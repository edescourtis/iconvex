/* SPDX-License-Identifier: LGPL-2.1-or-later */

#define _POSIX_C_SOURCE 200809L

#include <errno.h>
#include <iconv.h>
#include <inttypes.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#define OUTPUT_BUFFER_SIZE (64U * 1024U)
#define MIN_SAMPLE_NS UINT64_C(1000000)
#define MAX_BATCH_ITERATIONS (1U << 20)

#if !defined(_LIBICONV_VERSION) || _LIBICONV_VERSION != 0x0113
#error "gnu_iconv_engine_benchmark requires GNU libiconv 1.19 headers"
#endif

struct input_buffer {
  char *bytes;
  size_t size;
};

struct measurement {
  uint64_t elapsed_ns;
  size_t output_bytes;
  unsigned int iterations;
};

static void usage(const char *program) {
  fprintf(stderr,
          "usage: %s --samples N --from ENCODING --to ENCODING --input FILE\n",
          program);
}

static void die(const char *message) {
  fprintf(stderr, "%s: %s\n", message, strerror(errno));
  exit(EXIT_FAILURE);
}

static struct input_buffer read_input(const char *path) {
  FILE *file = fopen(path, "rb");
  long length;
  struct input_buffer input;

  if (file == NULL) {
    die("cannot open input");
  }

  if (fseek(file, 0, SEEK_END) != 0) {
    die("cannot seek input");
  }

  length = ftell(file);
  if (length < 0) {
    die("cannot measure input");
  }

  if (fseek(file, 0, SEEK_SET) != 0) {
    die("cannot rewind input");
  }

  input.size = (size_t)length;
  input.bytes = malloc(input.size == 0 ? 1 : input.size);
  if (input.bytes == NULL) {
    die("cannot allocate input");
  }

  if (input.size > 0 && fread(input.bytes, 1, input.size, file) != input.size) {
    die("cannot read input");
  }

  if (fclose(file) != 0) {
    die("cannot close input");
  }

  return input;
}

static uint64_t elapsed_nanoseconds(const struct timespec *started,
                                    const struct timespec *finished) {
  uint64_t started_ns = (uint64_t)started->tv_sec * UINT64_C(1000000000) +
                        (uint64_t)started->tv_nsec;
  uint64_t finished_ns = (uint64_t)finished->tv_sec * UINT64_C(1000000000) +
                         (uint64_t)finished->tv_nsec;

  return finished_ns - started_ns;
}

static struct measurement measure_batch(const struct input_buffer *input,
                                        const char *from, const char *to,
                                        unsigned int iterations) {
  iconv_t converter = iconv_open(to, from);
  char output[OUTPUT_BUFFER_SIZE];
  size_t expected_output_bytes = 0;
  struct timespec started;
  struct timespec finished;
  struct measurement result;

  if (converter == (iconv_t)-1) {
    die("iconv_open failed");
  }

  if (clock_gettime(CLOCK_MONOTONIC, &started) != 0) {
    die("cannot start monotonic clock");
  }

  for (unsigned int iteration = 0; iteration < iterations; iteration++) {
    char *input_cursor = input->bytes;
    size_t input_left = input->size;
    char *output_cursor = output;
    size_t output_left = sizeof(output);
    size_t output_bytes = 0;

    while (input_left > 0) {
      size_t converted = iconv(converter, &input_cursor, &input_left,
                               &output_cursor, &output_left);

      if (converted != (size_t)-1) {
        break;
      }

      if (errno != E2BIG) {
        die("iconv conversion failed");
      }

      output_bytes += sizeof(output) - output_left;
      output_cursor = output;
      output_left = sizeof(output);
    }

    for (;;) {
      size_t flushed = iconv(converter, NULL, NULL, &output_cursor, &output_left);

      if (flushed != (size_t)-1) {
        break;
      }

      if (errno != E2BIG) {
        die("iconv flush failed");
      }

      output_bytes += sizeof(output) - output_left;
      output_cursor = output;
      output_left = sizeof(output);
    }

    output_bytes += sizeof(output) - output_left;

    if (iteration == 0) {
      expected_output_bytes = output_bytes;
    } else if (output_bytes != expected_output_bytes) {
      fprintf(stderr, "batch output size changed: %zu != %zu\n", output_bytes,
              expected_output_bytes);
      exit(EXIT_FAILURE);
    }
  }

  if (clock_gettime(CLOCK_MONOTONIC, &finished) != 0) {
    die("cannot stop monotonic clock");
  }

  if (iconv_close(converter) != 0) {
    die("iconv_close failed");
  }

  result.elapsed_ns = elapsed_nanoseconds(&started, &finished);
  result.output_bytes = expected_output_bytes;
  result.iterations = iterations;
  return result;
}

static struct measurement measure_sample(const struct input_buffer *input,
                                         const char *from, const char *to) {
  unsigned int iterations = 1;

  for (;;) {
    struct measurement measured =
        measure_batch(input, from, to, iterations);

    if (measured.elapsed_ns >= MIN_SAMPLE_NS ||
        iterations >= MAX_BATCH_ITERATIONS) {
      return measured;
    }

    iterations *= 2;
  }
}

static unsigned int parse_samples(const char *value) {
  char *end = NULL;
  unsigned long parsed;

  errno = 0;
  parsed = strtoul(value, &end, 10);

  if (errno != 0 || end == value || *end != '\0' || parsed == 0 ||
      parsed > 1000) {
    fprintf(stderr, "invalid sample count: %s\n", value);
    exit(EXIT_FAILURE);
  }

  return (unsigned int)parsed;
}

int main(int argc, char **argv) {
  const char *from = NULL;
  const char *to = NULL;
  const char *input_path = NULL;
  unsigned int samples = 0;
  unsigned int sample;
  double best_us = -1.0;
  unsigned int best_iterations = 0;
  size_t expected_output_bytes = 0;
  struct input_buffer input;

  for (int index = 1; index < argc; index++) {
    if (strcmp(argv[index], "--samples") == 0 && index + 1 < argc) {
      samples = parse_samples(argv[++index]);
    } else if (strcmp(argv[index], "--from") == 0 && index + 1 < argc) {
      from = argv[++index];
    } else if (strcmp(argv[index], "--to") == 0 && index + 1 < argc) {
      to = argv[++index];
    } else if (strcmp(argv[index], "--input") == 0 && index + 1 < argc) {
      input_path = argv[++index];
    } else {
      usage(argv[0]);
      return EXIT_FAILURE;
    }
  }

  if (samples == 0 || from == NULL || to == NULL || input_path == NULL) {
    usage(argv[0]);
    return EXIT_FAILURE;
  }

  if (_libiconv_version != _LIBICONV_VERSION) {
    fprintf(stderr, "GNU libiconv header/runtime version mismatch: %x != %x\n",
            _LIBICONV_VERSION, _libiconv_version);
    return EXIT_FAILURE;
  }

  /* Input acquisition is intentionally outside every CLOCK_MONOTONIC window. */
  input = read_input(input_path);

  for (sample = 0; sample < samples; sample++) {
    struct measurement measured = measure_sample(&input, from, to);
    double measured_us =
        (double)measured.elapsed_ns / (double)measured.iterations / 1000.0;

    if (sample == 0) {
      expected_output_bytes = measured.output_bytes;
    } else if (measured.output_bytes != expected_output_bytes) {
      fprintf(stderr, "sample output size changed: %zu != %zu\n",
              measured.output_bytes, expected_output_bytes);
      free(input.bytes);
      return EXIT_FAILURE;
    }

    if (best_us < 0.0 || measured_us < best_us) {
      best_us = measured_us;
      best_iterations = measured.iterations;
    }
  }

  printf("engine_us=%.6f\n", best_us);
  printf("samples=%u\n", samples);
  printf("batch_iterations=%u\n", best_iterations);
  printf("input_bytes=%zu\n", input.size);
  printf("output_bytes=%zu\n", expected_output_bytes);
  printf("libiconv_version=1.19\n");

  free(input.bytes);
  return EXIT_SUCCESS;
}
