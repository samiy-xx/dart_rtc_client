part of rtc_client;

const int SIZEOF8 = 1;
const int SIZEOF16 = 2;
const int SIZEOF32 = 4;
const int NULL_BYTE = 0x00;
const int FULL_BYTE = 0xFF;
const int BINARY_TYPE_STRING = 0x10;
const int BINARY_TYPE_PACKET = 0x11;
const int BINARY_TYPE_FILE = 0x12;

const int BINARY_PACKET_ACK = 0x01;
const int BINARY_PACKET_RESEND = 0x02;
const int BINARY_PACKET_REQUEST_RESEND = 0x03;

const int PROTOCOL_STARTBYTE_POSITION = 0;
const int PROTOCOL_PACKETTYPE_POSITION = 1;
const int PROTOCOL_SEQUENCE_POSITION = 2;
const int PROTOCOL_TOTALSEQUENCE_POSITION = 4;
const int PROTOCOL_BYTELENGTH_POSITION = 6;
const int PROTOCOL_TOTALBYTELENGTH_POSITION = 8;
const int PROTOCOL_SIGNATURE_POSITION = 12;
const int PROTOCOL_FIRST_CONTENT_POSITION = 16;
/**
 * Binary reader/writer for Datachannel
 */
class BinaryData {

  static ArrayBuffer bufferFromString(String s) {
    ArrayBuffer buffer = new ArrayBuffer(s.length);
    Uint8Array array = new Uint8Array.fromBuffer(buffer);

    for (int i = 0; i < s.length; i++) {
      array[i] = s.codeUnitAt(i);
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
    ArrayBuffer ackBuffer = new ArrayBuffer(17);
    DataView viewOriginal = new DataView(b, 0, 16);
    DataView viewAck = new DataView(ackBuffer);

    viewAck.setUint8(
        PROTOCOL_STARTBYTE_POSITION,
        viewOriginal.getUint8(PROTOCOL_STARTBYTE_POSITION)
    );

    viewAck.setUint8(
        PROTOCOL_PACKETTYPE_POSITION,
        viewOriginal.getUint8(PROTOCOL_PACKETTYPE_POSITION)
    );

    viewAck.setUint16(
        PROTOCOL_SEQUENCE_POSITION,
        viewOriginal.getUint16(PROTOCOL_SEQUENCE_POSITION)
    );

    viewAck.setUint16(
        PROTOCOL_TOTALSEQUENCE_POSITION,
        viewOriginal.getUint16(PROTOCOL_TOTALSEQUENCE_POSITION)
    );

    viewAck.setUint16(
        PROTOCOL_BYTELENGTH_POSITION,
        viewOriginal.getUint16(PROTOCOL_BYTELENGTH_POSITION)
    );

    viewAck.setUint32(
        PROTOCOL_TOTALBYTELENGTH_POSITION,
        viewOriginal.getUint32(PROTOCOL_TOTALBYTELENGTH_POSITION)
    );

    viewAck.setUint32(
        PROTOCOL_SIGNATURE_POSITION,
        viewOriginal.getUint32(PROTOCOL_SIGNATURE_POSITION)
    );

    viewAck.setUint8(PROTOCOL_FIRST_CONTENT_POSITION, BINARY_PACKET_ACK);
  }

  /**
   * Needs a bit of tuning =)
   */
  static bool hasHeader(ArrayBuffer buffer) {
    DataView view = new DataView(buffer, 0, 1);
    try {
      if (view.getUint8(PROTOCOL_STARTBYTE_POSITION) == 0xFF)
        return true;
    } catch (e) {}

    return false;

  }

  static bool isCommand(ArrayBuffer buffer) {
    if (buffer.byteLength == 17)
      return true;
  }

  static int getCommand(ArrayBuffer buffer) {
    return new DataView(buffer).getUint8(16);
  }

  static int getSignature(ArrayBuffer buffer) {
    DataView view = new DataView(buffer, 0, 16);
    return view.getUint32(PROTOCOL_SIGNATURE_POSITION);
  }

  static int getSequenceNumber(ArrayBuffer buffer) {
    DataView view = new DataView(buffer, 0, 16);
    return view.getUint16(PROTOCOL_SEQUENCE_POSITION);
  }

  static bool isValid(ArrayBuffer buf) {
    DataView view = new DataView(buf, 0, 16);
    try {
      if (view.getUint8(PROTOCOL_STARTBYTE_POSITION) != FULL_BYTE) { // 0
        new Logger().Warning("binarydata.dart Failed checking start byte");
        return false;
      }

      int packetType = view.getUint8(PROTOCOL_PACKETTYPE_POSITION); // 1
      if (packetType == null) {
        new Logger().Warning("binarydata.dart Failed checking packetType");
        return false;
      }

      int sequenceNumber = view.getUint16(PROTOCOL_SEQUENCE_POSITION); // 2
      if (sequenceNumber == null || sequenceNumber < 1) {
        new Logger().Warning("binarydata.dart Failed checking sequenceNumber");
        return false;
      }

      int totalSequences = view.getUint16(PROTOCOL_TOTALSEQUENCE_POSITION); // 4
      if (totalSequences == null || totalSequences < sequenceNumber) {
        new Logger().Warning("binarydata.dart Failed checking totalSequences");
        return false;
      }

      int byteLength = view.getUint16(PROTOCOL_BYTELENGTH_POSITION); // 6
      if (byteLength == null || byteLength <= 0) {
        new Logger().Warning("binarydata.dart Failed checking byteLength");
        return false;
      }

      int totalBytes = view.getUint32(PROTOCOL_TOTALBYTELENGTH_POSITION); // 8
      if (totalBytes == null || totalBytes < byteLength) {
        new Logger().Warning("binarydata.dart Failed checking totalBytes");
        return false;
      }

      int signature = view.getUint32(PROTOCOL_SIGNATURE_POSITION); // 12
      int current = new DateTime.now().millisecondsSinceEpoch;
      if (signature == null) {
        new Logger().Warning("binarydata.dart Failed checking signature");
        return false;
      }

      return true;

    } catch(e, s) {
      new Logger().Error("Error $e");

    }

    return false;
  }
}

