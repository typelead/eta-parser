package eta.parser;

import eta.runtime.io.MemoryManager;
import java.nio.ByteBuffer;

public class Utils {

  // Copied from https://github.com/typelead/eta-hackage/blob/master/patches/bytestring-0.10.8.1.patch#L754
  public static int memcmp(long address1, long address2, int n) {
        ByteBuffer b1 = MemoryManager.getBoundedBuffer(address1);
        ByteBuffer b2 = MemoryManager.getBoundedBuffer(address2);
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
