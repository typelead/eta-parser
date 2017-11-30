package eta.parser;

import java.nio.ByteBuffer;

public class Utils {

  // Copied from https://github.com/typelead/eta-hackage/blob/535f422cb4a6edfa6c1e4d7486b69e6684ddd9e9/patches/bytestring-0.10.8.2.patch#L467
  public static int memcmp(ByteBuffer b1, ByteBuffer b2, int n) {
        /* TODO: Is the & 0xFF required? */
        while (n-- != 0) {
            int a = b1.get() & 0xFF;
            int b = b2.get() & 0xFF;
            if (a != b) {
                return a - b;
            }
        }
        return 0;
    }
}
