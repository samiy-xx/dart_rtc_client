part of rtc_client;

const int DATACHANNEL_TYPE_STRING = 0;
const int DATACHANNEL_TYPE_BYTE = 0;
const int DATACHANNEL_TYPE_BLOB = 0;

const String DATACHANNEL_LABEL_STRING = "__dc_label_string__";
const String DATACHANNEL_LABEL_BYTE = "__dc_label_byte__";
const String DATACHANNEL_LABEL_BLOB = "__dc_label_blob__";

class DataChannelContainer {
  final bool _createdLocally;
  bool _reliable;
  int _type;
  String _label;

  RtcDataChannel _channel;
  RtcPeerConnection _peer;
  PeerConnection _pc;
  DataReader _reader;
  DataWriter _writer;

  DataChannelContainer(PeerConnection pc, int type) : _createdLocally = true{
    _pc = pc;
    _peer = pc.peer;
    _type = type;
  }

  DataChannelContainer.remote(PeerConnection pc, RtcDataChannel channel) : _createdLocally = false {
    _pc = pc;
    _peer = pc.peer;
    _channel = channel;
    _channel.onClose.listen(_onClose);
    _channel.onOpen.listen(_onOpen);
    _channel.onError.listen(_onError);
  }

  void init() {
    if (_reader == null)
      throw new DataChannelSetupException("Reader not set");

    if (_writer == null)
      throw new DataChannelSetupException("Writer not set");

    if (_label == null)
      throw new DataChannelSetupException("Label not set");

    _channel = _peer.createDataChannel(_label, _createConstraints());
    _channel.onClose.listen(_onClose);
    _channel.onOpen.listen(_onOpen);
    _channel.onError.listen(_onError);
  }

  void setLabel(String label) {
    _label = label;
  }

  void setWriter(DataWriter writer) {
    _writer = writer;
  }

  void setReader(DataReader reader) {
    _reader = reader;
  }

  void _onError(RtcDataChannelEvent e) {

  }

  void _onOpen(Event e) {

  }

  void _onClose(Event e) {

  }

  Map _createConstraints() {
    Map m = new Map();

    return m;
  }
}