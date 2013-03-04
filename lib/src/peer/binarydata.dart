part of rtc_client;

const int SIZEOF8 = 1;
const int SIZEOF16 = 2;
const int SIZEOF32 = 4;
const int SIZEOF_UDP_HEADER = 16;
const int SIZEOF_TCP_HEADER = 12;

const int NULL_BYTE = 0x00;
const int FULL_BYTE = 0xFF;
const int BINARY_TYPE_STRING = 0x10;
const int BINARY_TYPE_PACKET = 0x11;
const int BINARY_TYPE_FILE = 0x12;

const int BINARY_PROTOCOL_UDP = 1;
const int BINARY_PROTOCOL_TCP = 2;

const int BINARY_PACKET_ACK = 0x01;
const int BINARY_PACKET_RESEND = 0x02;
const int BINARY_PACKET_REQUEST_RESEND = 0x03;

const int PROTOCOL_STARTBYTE_POSITION = 0;
const int PROTOCOL_PACKETTYPE_POSITION = 1;

const int UDP_PROTOCOL_SEQUENCE_POSITION = 2;
const int UDP_PROTOCOL_TOTALSEQUENCE_POSITION = 4;
const int UDP_PROTOCOL_BYTELENGTH_POSITION = 6;
const int UDP_PROTOCOL_TOTALBYTELENGTH_POSITION = 8;
const int UDP_PROTOCOL_SIGNATURE_POSITION = 12;
const int UDP_PROTOCOL_FIRST_CONTENT_POSITION = 16;

const int TCP_PROTOCOL_BYTELENGTH_POSITION = 2;
const int TCP_PROTOCOL_TOTALBYTELENGTH_POSITION = 4;
const int TCP_PROTOCOL_SIGNATURE_POSITION = 8;
const int TCP_PROTOCOL_FIRST_CONTENT_POSITION = 12;
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

  static ArrayBuffer createAck(int signature, int sequence) {
    ArrayBuffer ackBuffer = new ArrayBuffer(17);

    DataView viewAck = new DataView(ackBuffer);


    viewAck.setUint8(
        PROTOCOL_STARTBYTE_POSITION,
        FULL_BYTE
    );

    viewAck.setUint8(
        PROTOCOL_PACKETTYPE_POSITION,
        0x00
    );

    viewAck.setUint16(
        UDP_PROTOCOL_SEQUENCE_POSITION,
        sequence
    );

    viewAck.setUint16(
        UDP_PROTOCOL_TOTALSEQUENCE_POSITION,
        sequence
    );

    viewAck.setUint16(
        UDP_PROTOCOL_BYTELENGTH_POSITION,
        1
    );

    viewAck.setUint32(
        UDP_PROTOCOL_TOTALBYTELENGTH_POSITION,
        1
    );

    viewAck.setUint32(
        UDP_PROTOCOL_SIGNATURE_POSITION,
        signature
    );

    viewAck.setUint8(UDP_PROTOCOL_FIRST_CONTENT_POSITION, BINARY_PACKET_ACK);

    if (!isValid(ackBuffer,BINARY_PROTOCOL_UDP )) {
      new Logger().Warning("Created nonvalid ack response");
    }
    return ackBuffer;
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

    return false;
  }

  static int getCommand(ArrayBuffer buffer) {
    return new DataView(buffer).getUint8(16);
  }

  static int getSignature(ArrayBuffer buffer) {
    DataView view = new DataView(buffer, 0, 16);
    return view.getUint32(UDP_PROTOCOL_SIGNATURE_POSITION);
  }

  static int getSequenceNumber(ArrayBuffer buffer) {
    DataView view = new DataView(buffer, 0, 16);
    return view.getUint16(UDP_PROTOCOL_SEQUENCE_POSITION);
  }

  static ArrayBuffer writeUdpHeader(ArrayBuffer buf, int packetType, int sequenceNumber, int totalSequences, int signature, int total) {
    Uint8Array content = new Uint8Array.fromBuffer(buf);
    ArrayBuffer resultBuffer = new ArrayBuffer(buf.byteLength + SIZEOF_UDP_HEADER);
    DataView writer = new DataView(resultBuffer);

    writer.setUint8(PROTOCOL_STARTBYTE_POSITION, FULL_BYTE); // 0
    writer.setUint8(PROTOCOL_PACKETTYPE_POSITION, packetType); // 1
    writer.setUint16(UDP_PROTOCOL_SEQUENCE_POSITION, sequenceNumber); // 2
    writer.setUint16(UDP_PROTOCOL_TOTALSEQUENCE_POSITION, totalSequences); //4
    writer.setUint16(UDP_PROTOCOL_BYTELENGTH_POSITION, buf.byteLength); //6
    writer.setUint32(UDP_PROTOCOL_TOTALBYTELENGTH_POSITION, total); //8
    writer.setUint32(UDP_PROTOCOL_SIGNATURE_POSITION, signature); //12

    for (int i = 0; i < content.length; i++) {
      writer.setUint8(i + UDP_PROTOCOL_FIRST_CONTENT_POSITION, content[i]);
    }

    return writer.buffer;
  }

  static ArrayBuffer writeTcpHeader(ArrayBuffer buf, int packetType, int signature, int total) {
    Uint8Array content = new Uint8Array.fromBuffer(buf);
    ArrayBuffer resultBuffer = new ArrayBuffer(buf.byteLength + SIZEOF_TCP_HEADER);
    DataView writer = new DataView(resultBuffer);

    writer.setUint8(PROTOCOL_STARTBYTE_POSITION, FULL_BYTE); // 0
    writer.setUint8(PROTOCOL_PACKETTYPE_POSITION, packetType); // 1
    writer.setUint16(TCP_PROTOCOL_BYTELENGTH_POSITION, buf.byteLength); // 2
    writer.setUint32(TCP_PROTOCOL_TOTALBYTELENGTH_POSITION, total);
    writer.setUint32(TCP_PROTOCOL_SIGNATURE_POSITION, signature);

    for (int i = 0; i < content.length; i++) {
      writer.setUint8(i + TCP_PROTOCOL_FIRST_CONTENT_POSITION, content[i]);
    }

    return writer.buffer;
  }

  static bool isValid(ArrayBuffer buffer, int protocol) {
    if (protocol == BINARY_PROTOCOL_UDP){
      return isValidUdp(buffer);
    } else {
      return isValidTcp(buffer);
    }
  }

  static bool isValidTcp(ArrayBuffer buf) {
    DataView view = new DataView(buf, 0, SIZEOF_TCP_HEADER);

    if (view.getUint8(PROTOCOL_STARTBYTE_POSITION) != FULL_BYTE) { // 0
      new Logger().Warning("binarydata.dart Failed checking start byte");
      return false;
    }

    int packetType = view.getUint8(PROTOCOL_PACKETTYPE_POSITION); // 1
    if (packetType == null) {
      new Logger().Warning("binarydata.dart Failed checking packetType");
      return false;
    }

    int byteLength = view.getUint16(TCP_PROTOCOL_BYTELENGTH_POSITION); // 2
    if (byteLength == null || byteLength <= 0) {
      new Logger().Warning("binarydata.dart Failed checking byteLength");
      return false;
    }

    int totalBytes = view.getUint32(TCP_PROTOCOL_TOTALBYTELENGTH_POSITION); // 4
    if (totalBytes == null || totalBytes < byteLength) {
      new Logger().Warning("binarydata.dart Failed checking totalBytes");
      return false;
    }

    int signature = view.getUint32(TCP_PROTOCOL_SIGNATURE_POSITION); // 8
    int current = new DateTime.now().millisecondsSinceEpoch;
    if (signature == null) {
      new Logger().Warning("binarydata.dart Failed checking signature");
      return false;
    }

    return true;
  }

  static bool isValidUdp(ArrayBuffer buf) {
    DataView view = new DataView(buf, 0, SIZEOF_UDP_HEADER);
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

      int sequenceNumber = view.getUint16(UDP_PROTOCOL_SEQUENCE_POSITION); // 2
      if (sequenceNumber == null || sequenceNumber < 1) {
        new Logger().Warning("binarydata.dart Failed checking sequenceNumber");
        return false;
      }

      int totalSequences = view.getUint16(UDP_PROTOCOL_TOTALSEQUENCE_POSITION); // 4
      if (totalSequences == null || totalSequences < sequenceNumber) {
        new Logger().Warning("binarydata.dart Failed checking totalSequences");
        return false;
      }

      int byteLength = view.getUint16(UDP_PROTOCOL_BYTELENGTH_POSITION); // 6
      if (byteLength == null || byteLength <= 0) {
        new Logger().Warning("binarydata.dart Failed checking byteLength");
        return false;
      }

      int totalBytes = view.getUint32(UDP_PROTOCOL_TOTALBYTELENGTH_POSITION); // 8
      if (totalBytes == null || totalBytes < byteLength) {
        new Logger().Warning("binarydata.dart Failed checking totalBytes");
        return false;
      }

      int signature = view.getUint32(UDP_PROTOCOL_SIGNATURE_POSITION); // 12
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

