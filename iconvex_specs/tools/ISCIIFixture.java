import java.io.*;
import java.nio.*;
import java.nio.charset.*;
import java.util.*;

public final class ISCIIFixture {
  private static final int[][] EXTRA_SEQUENCES = {
    {0x094d, 0x200c}, {0x094d, 0x200d},
    {0x09cd, 0x200c}, {0x09cd, 0x200d},
    {0x0a4d, 0x200c}, {0x0a4d, 0x200d},
    {0x0acd, 0x200c}, {0x0acd, 0x200d},
    {0x0b4d, 0x200c}, {0x0b4d, 0x200d},
    {0x0bcd, 0x200c}, {0x0bcd, 0x200d},
    {0x0c4d, 0x200c}, {0x0c4d, 0x200d},
    {0x0ccd, 0x200c}, {0x0ccd, 0x200d},
    {0x0d4d, 0x200c}, {0x0d4d, 0x200d}
  };

  public static void main(String[] args) throws Exception {
    if (args.length != 1) throw new IllegalArgumentException("output path required");

    try (PrintWriter out = new PrintWriter(new OutputStreamWriter(new FileOutputStream(args[0]), "UTF-8"))) {
      out.println("# ICU4J 78.1 ISCII exhaustive generated fixture");

      for (int version = 0; version < 9; version++) {
        Charset charset = Charset.forName("ISCII,version=" + version);
        Map<Integer, int[]> singles = new HashMap<>();
        Map<Integer, int[]> pairs = new HashMap<>();

        for (int b = 0; b <= 0xff; b++) {
          int[] decoded = decode(charset, new byte[]{(byte)b});
          if (decoded != null) {
            singles.put(b, decoded);
            row(out, "D", version, hex(new byte[]{(byte)b}), codepoints(decoded));
          }
        }

        for (int first = 0xa0; first <= 0xfa; first++) {
          if (first == 0xef) continue;
          for (int second = 0xa0; second <= 0xfa; second++) {
            byte[] bytes = {(byte)first, (byte)second};
            int[] decoded = decode(charset, bytes);
            int[] ordinary = concat(singles.get(first), singles.get(second));

            if (decoded != null && !Arrays.equals(decoded, ordinary)) {
              pairs.put((first << 8) | second, decoded);
              row(out, "D", version, hex(bytes), codepoints(decoded));
            }
          }
        }

        if (version == 2) {
          for (int first = 0xa0; first <= 0xfa; first++) {
            for (int third = 0xa0; third <= 0xfa; third++) {
              byte[] bytes = {(byte)first, (byte)0xe8, (byte)third};
              int[] decoded = decode(charset, bytes);
              int[] greedy = greedy(bytes, singles, pairs);

              if (decoded != null && !Arrays.equals(decoded, greedy)) {
                row(out, "D", version, hex(bytes), codepoints(decoded));
              }
            }
          }
        }

        for (int cp = 0; cp <= 0xa0; cp++) encodeRow(out, charset, version, new int[]{cp});
        for (int cp = 0x0900; cp <= 0x0d7f; cp++) encodeRow(out, charset, version, new int[]{cp});
        encodeRow(out, charset, version, new int[]{0x200c});
        encodeRow(out, charset, version, new int[]{0x200d});

        for (int[] sequence : EXTRA_SEQUENCES) encodeRow(out, charset, version, sequence);
        for (int consonant = 0x0a15; consonant <= 0x0a39; consonant++) {
          encodeRow(out, charset, version, new int[]{0x0a71, consonant});
        }
      }
    }
  }

  private static void encodeRow(PrintWriter out, Charset charset, int version, int[] cps) {
    byte[] encoded = encode(charset, cps);
    if (encoded != null) row(out, "E", version, codepoints(cps), hex(encoded));
  }

  private static int[] decode(Charset charset, byte[] bytes) {
    try {
      CharsetDecoder decoder = charset.newDecoder()
        .onMalformedInput(CodingErrorAction.REPORT)
        .onUnmappableCharacter(CodingErrorAction.REPORT);
      CharBuffer chars = decoder.decode(ByteBuffer.wrap(bytes));
      return chars.toString().codePoints().toArray();
    } catch (CharacterCodingException error) {
      return null;
    }
  }

  private static byte[] encode(Charset charset, int[] cps) {
    try {
      String text = new String(cps, 0, cps.length);
      CharsetEncoder encoder = charset.newEncoder()
        .onMalformedInput(CodingErrorAction.REPORT)
        .onUnmappableCharacter(CodingErrorAction.REPORT);
      ByteBuffer bytes = encoder.encode(CharBuffer.wrap(text));
      byte[] result = new byte[bytes.remaining()];
      bytes.get(result);
      return result;
    } catch (CharacterCodingException error) {
      return null;
    }
  }

  private static int[] greedy(byte[] bytes, Map<Integer, int[]> singles, Map<Integer, int[]> pairs) {
    List<Integer> output = new ArrayList<>();
    int index = 0;

    while (index < bytes.length) {
      int first = bytes[index] & 0xff;
      int[] value = null;

      if (index + 1 < bytes.length) {
        value = pairs.get((first << 8) | (bytes[index + 1] & 0xff));
        if (value != null) index += 2;
      }

      if (value == null) {
        value = singles.get(first);
        index++;
      }

      if (value == null) return null;
      for (int cp : value) output.add(cp);
    }

    return output.stream().mapToInt(Integer::intValue).toArray();
  }

  private static int[] concat(int[] first, int[] second) {
    if (first == null || second == null) return null;
    int[] output = Arrays.copyOf(first, first.length + second.length);
    System.arraycopy(second, 0, output, first.length, second.length);
    return output;
  }

  private static String hex(byte[] bytes) {
    StringBuilder output = new StringBuilder();
    for (byte value : bytes) output.append(String.format("%02X", value & 0xff));
    return output.toString();
  }

  private static String codepoints(int[] cps) {
    StringJoiner output = new StringJoiner(",");
    for (int cp : cps) output.add(String.format("%X", cp));
    return output.toString();
  }

  private static void row(PrintWriter out, String kind, int version, String first, String second) {
    out.print(kind); out.print('\t'); out.print(version); out.print('\t');
    out.print(first); out.print('\t'); out.println(second);
  }
}
