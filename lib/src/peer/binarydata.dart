part of rtc_client;

const int SIZEOF8 = 1;
const int SIZEOF16 = 2;
const int SIZEOF32 = 4;
const int NULL_BYTE = 0x00;
const int FULL_BYTE = 0xFF;
const int BINARY_TYPE_STRING = 0x10;
const int BINARY_TYPE_PACKET = 0x11;
const int BINARY_TYPE_FILE = 0x12;
const int BINARY_PACKET_ACK = 0xFF;

/**
 * Binary reader/writer for Datachannel
 */
class BinaryData {

  static ArrayBuffer bufferFromString(String s) {
    ArrayBuffer buffer = new ArrayBuffer(s.length);
    DataView view = new DataView(buffer);

    for (int i = 0; i < s.length; i++) {
      view.setUint8(0, s.codeUnitAt(i));
    }

    return buffer;
  }

  /**
   * Creates ArrayBuffer from Packet
   */
  static ArrayBuffer bufferFromPacket(Packet p) {
    String packet = PacketFactory.get(p);
    return bufferFromString(packet);
  }

  /**
   * Converts list of integers to string
   */
  static String stringFromList(List<int> l) {
    return new String.fromCharCodes(l);
  }

  /**
   * Converts ArrayBuffer to string
   */
  static String stringFromBuffer(ArrayBuffer buffer) {
    Uint8Array view = new Uint8Array.fromBuffer(buffer);
    return new String.fromCharCodes(view.toList());
  }

  /**
   * Converts ArrayBuffer to Packet
   */
  static Packet packetFromBuffer(ArrayBuffer buffer) {
    PacketFactory.getPacketFromString(stringFromBuffer(buffer));
  }

  static ArrayBuffer createAck(ArrayBuffer b) {
    ArrayBuffer ackBuffer = new ArrayBuffer(15);
    DataView viewOriginal = new DataView(b, 0, 14);
    DataView viewAck = new DataView(ackBuffer);

    viewAck.setUint8(0, viewOriginal.getUint8(0));
    viewAck.setUint16(1, viewOriginal.getUint16(1));
    viewAck.setUint16(3, viewOriginal.getUint16(3));
    viewAck.setUint16(5, viewOriginal.getUint16(5));
    viewAck.setUint32(7, viewOriginal.getUint32(7));
    viewAck.setUint32(11, viewOriginal.getUint32(11));
    viewAck.setUint8(15, BINARY_PACKET_ACK);
  }

  /**
   * Needs a bit of tuning =)
   */
  static bool hasHeader(ArrayBuffer buffer) {
    DataView view = new DataView(buffer, 0, 14);
    try {
      if (view.getUint8(0) == 0xFF)
        return true;
    } catch (e) {}

    return false;

  }

  static bool isValid(ArrayBuffer buf) {
    DataView view = new DataView(buf, 0, 14);
    try {
      if (view.getUint8(0) != FULL_BYTE)
        return false;

      int sequenceNumber = view.getUint16(1);
      if (sequenceNumber == null || sequenceNumber < 1)
        return false;

      int totalSequences = view.getUint16(3);
      if (totalSequences == null || totalSequences < sequenceNumber)
        return false;

      int byteLength = view.getUint16(5);
      if (byteLength == null || byteLength <= 0)
        return false;

      int totalBytes = view.getUint32(7);
      if (totalBytes == null || totalBytes < byteLength)
        return false;

      int timeStamp = view.getUint32(11);
      int current = new DateTime.now().millisecondsSinceEpoch;
      if (timeStamp == null || (timeStamp + 60000) < current)
        return false;

      return true;

    } catch(e) {}

    return false;
  }
}

