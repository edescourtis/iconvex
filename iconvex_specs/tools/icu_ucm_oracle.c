#include <errno.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <unicode/ucnv.h>
#include <unicode/utf16.h>

static void print_bytes(const char *bytes, int32_t length) {
  for (int32_t index = 0; index < length; index++) {
    printf("%02X", (unsigned char)bytes[index]);
  }
}

static int hex_value(char value) {
  if (value >= '0' && value <= '9') return value - '0';
  if (value >= 'A' && value <= 'F') return value - 'A' + 10;
  if (value >= 'a' && value <= 'f') return value - 'a' + 10;
  return -1;
}

static void decode(UConverter *converter, const char *hex) {
  char input[64];
  int32_t input_length = 0;
  size_t hex_length = strlen(hex);

  if ((hex_length & 1) != 0 || hex_length / 2 > sizeof(input)) {
    printf("HARNESS_ERROR\n");
    return;
  }

  for (size_t offset = 0; offset < hex_length; offset += 2) {
    int high = hex_value(hex[offset]);
    int low = hex_value(hex[offset + 1]);
    if (high < 0 || low < 0) {
      printf("HARNESS_ERROR\n");
      return;
    }
    input[input_length++] = (char)((high << 4) | low);
  }

  UChar output[32];
  UErrorCode status = U_ZERO_ERROR;
  int32_t length =
      ucnv_toUChars(converter, output, 32, input, input_length, &status);

  if (U_FAILURE(status)) {
    printf("ERR\n");
    return;
  }

  printf("OK ");
  int32_t offset = 0;
  int first = 1;
  while (offset < length) {
    UChar32 codepoint;
    U16_NEXT(output, offset, length, codepoint);
    printf(first ? "%X" : ",%X", (unsigned int)codepoint);
    first = 0;
  }
  printf("\n");
}

static int append_codepoint(UChar *output, int32_t *length, UChar32 codepoint) {
  UBool error = 0;
  U16_APPEND(output, *length, 64, codepoint, error);
  return error ? 0 : 1;
}

static void encode(UConverter *converter, char *values) {
  UChar input[64];
  int32_t input_length = 0;
  char *cursor = values;

  while (*cursor != '\0') {
    errno = 0;
    char *end;
    unsigned long value = strtoul(cursor, &end, 16);
    if (errno || end == cursor || value > 0x10ffff ||
        !append_codepoint(input, &input_length, (UChar32)value)) {
      printf("HARNESS_ERROR\n");
      return;
    }
    cursor = *end == ',' ? end + 1 : end;
  }

  char output[64];
  UErrorCode status = U_ZERO_ERROR;
  int32_t length =
      ucnv_fromUChars(converter, output, 64, input, input_length, &status);

  if (U_FAILURE(status)) {
    printf("ERR\n");
    return;
  }

  printf("OK ");
  print_bytes(output, length);
  printf("\n");
}

int main(int argc, char **argv) {
  if (argc != 3) {
    fprintf(stderr, "usage: %s CONVERTER REQUEST_FILE\n", argv[0]);
    return 2;
  }

  UErrorCode status = U_ZERO_ERROR;
  const char *package = getenv("ICU_UCM_PACKAGE");
  UConverter *converter =
      package && *package ? ucnv_openPackage(package, argv[1], &status)
                          : ucnv_open(argv[1], &status);
  if (U_FAILURE(status)) {
    fprintf(stderr, "cannot open %s: %s\n", argv[1], u_errorName(status));
    return 3;
  }

  ucnv_setFallback(converter, 0);
  status = U_ZERO_ERROR;
  ucnv_setToUCallBack(converter, UCNV_TO_U_CALLBACK_STOP, NULL, NULL, NULL, &status);
  ucnv_setFromUCallBack(converter, UCNV_FROM_U_CALLBACK_STOP, NULL, NULL, NULL,
                       &status);
  if (U_FAILURE(status)) {
    fprintf(stderr, "cannot configure callbacks: %s\n", u_errorName(status));
    ucnv_close(converter);
    return 4;
  }

  FILE *requests = fopen(argv[2], "r");
  if (!requests) {
    perror("request file");
    ucnv_close(converter);
    return 5;
  }

  char line[1024];
  while (fgets(line, sizeof(line), requests)) {
    line[strcspn(line, "\r\n")] = '\0';
    ucnv_reset(converter);

    if (line[0] == 'D' && line[1] == ' ') {
      decode(converter, line + 2);
    } else if (line[0] == 'E' && line[1] == ' ') {
      encode(converter, line + 2);
    } else {
      printf("HARNESS_ERROR\n");
    }
  }

  fclose(requests);
  ucnv_close(converter);
  return 0;
}
