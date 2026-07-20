#include <limits.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#include <unicode/ucnv.h>
#include <unicode/ustring.h>

static void fail(const char *message) {
  fprintf(stderr, "%s\n", message);
  exit(2);
}

static void fail_icu(const char *operation, UErrorCode status) {
  fprintf(stderr, "%s: %s\n", operation, u_errorName(status));
  exit(2);
}

static unsigned char *read_file(const char *path, int32_t *length) {
  FILE *file = fopen(path, "rb");
  long size;
  unsigned char *buffer;

  if (file == NULL) fail("cannot open benchmark input");
  if (fseek(file, 0, SEEK_END) != 0) fail("cannot seek benchmark input");
  size = ftell(file);
  if (size < 0 || size > INT32_MAX) fail("benchmark input is too large");
  if (fseek(file, 0, SEEK_SET) != 0) fail("cannot rewind benchmark input");

  buffer = (unsigned char *)malloc((size_t)size + 1);
  if (buffer == NULL) fail("cannot allocate benchmark input");
  if (size > 0 && fread(buffer, 1, (size_t)size, file) != (size_t)size)
    fail("cannot read benchmark input");
  fclose(file);
  *length = (int32_t)size;
  return buffer;
}

static uint64_t monotonic_ns(void) {
  struct timespec value;
  if (clock_gettime(CLOCK_MONOTONIC, &value) != 0) fail("clock_gettime failed");
  return (uint64_t)value.tv_sec * UINT64_C(1000000000) + (uint64_t)value.tv_nsec;
}

int main(int argc, char **argv) {
  const char *mode;
  const char *encoding;
  const char *path;
  int iterations;
  UErrorCode status = U_ZERO_ERROR;
  UConverter *converter;
  int32_t input_length;
  unsigned char *input;
  uint64_t started;
  uint64_t elapsed = 0;
  uint64_t checksum = 0;
  int32_t output_length = 0;
  int sample;

  if (argc != 5) fail("usage: oracle encode|decode ENCODING INPUT ITERATIONS");
  mode = argv[1];
  encoding = argv[2];
  path = argv[3];
  iterations = atoi(argv[4]);
  if (iterations <= 0) fail("iterations must be positive");

  converter = ucnv_open(encoding, &status);
  if (U_FAILURE(status)) fail_icu("ucnv_open", status);
  input = read_file(path, &input_length);

  if (strcmp(mode, "encode") == 0) {
    UChar *unicode;
    int32_t unicode_length = 0;
    int32_t output_capacity;
    char *output;

    status = U_ZERO_ERROR;
    u_strFromUTF8(NULL, 0, &unicode_length, (const char *)input, input_length, &status);
    if (status != U_BUFFER_OVERFLOW_ERROR) fail_icu("u_strFromUTF8 preflight", status);
    status = U_ZERO_ERROR;
    unicode = (UChar *)malloc(((size_t)unicode_length + 1) * sizeof(UChar));
    if (unicode == NULL) fail("cannot allocate UTF-16 benchmark input");
    u_strFromUTF8(unicode, unicode_length + 1, NULL, (const char *)input, input_length, &status);
    if (U_FAILURE(status)) fail_icu("u_strFromUTF8", status);

    output_capacity = unicode_length * 6 + 32;
    output = (char *)malloc((size_t)output_capacity);
    if (output == NULL) fail("cannot allocate encoded benchmark output");

    for (sample = 0; sample < 25; sample++) {
      status = U_ZERO_ERROR;
      ucnv_resetFromUnicode(converter);
      output_length =
          ucnv_fromUChars(converter, output, output_capacity, unicode, unicode_length, &status);
      if (U_FAILURE(status)) fail_icu("ucnv_fromUChars warmup", status);
      checksum += (uint64_t)output_length;
    }

    started = monotonic_ns();
    for (sample = 0; sample < iterations; sample++) {
      status = U_ZERO_ERROR;
      ucnv_resetFromUnicode(converter);
      output_length =
          ucnv_fromUChars(converter, output, output_capacity, unicode, unicode_length, &status);
      if (U_FAILURE(status)) fail_icu("ucnv_fromUChars", status);
      checksum += (uint64_t)output_length;
    }
    elapsed = monotonic_ns() - started;
    free(output);
    free(unicode);
  } else if (strcmp(mode, "decode") == 0) {
    int32_t output_capacity = input_length * 2 + 32;
    UChar *output = (UChar *)malloc((size_t)output_capacity * sizeof(UChar));
    if (output == NULL) fail("cannot allocate decoded benchmark output");

    for (sample = 0; sample < 25; sample++) {
      status = U_ZERO_ERROR;
      ucnv_resetToUnicode(converter);
      output_length = ucnv_toUChars(converter, output, output_capacity,
                                    (const char *)input, input_length, &status);
      if (U_FAILURE(status)) fail_icu("ucnv_toUChars warmup", status);
      checksum += (uint64_t)output_length;
    }

    started = monotonic_ns();
    for (sample = 0; sample < iterations; sample++) {
      status = U_ZERO_ERROR;
      ucnv_resetToUnicode(converter);
      output_length = ucnv_toUChars(converter, output, output_capacity,
                                    (const char *)input, input_length, &status);
      if (U_FAILURE(status)) fail_icu("ucnv_toUChars", status);
      checksum += (uint64_t)output_length;
    }
    elapsed = monotonic_ns() - started;
    free(output);
  } else {
    fail("mode must be encode or decode");
  }

  printf("%.3f %d %llu\n", (double)elapsed / (double)iterations, output_length,
         (unsigned long long)checksum);
  free(input);
  ucnv_close(converter);
  return 0;
}
