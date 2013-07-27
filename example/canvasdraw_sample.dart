import "dart:html";
import "dart:async";
import 'dart:json' as json;
import '../lib/rtc_client.dart';
import 'peerpacket.dart';

void main() {
  final String key = query("#key").text;
  final int channelLimit = 10;

  PeerClient client = new PeerClient(new WebSocketDataSource("ws://127.0.0.1:8234/ws"))
  .setRequireAudio(Browser.isFirefox)
  .setRequireVideo(false)
  .setRequireDataChannel(true)
  .setAutoCreatePeer(true);

  CanvasDraw draw = new CanvasDraw(query("#drawcanvas"), client);

  client.onInitializationStateChangeEvent.listen((InitializationStateEvent e) {
    if (e.state == InitializationState.CHANNEL_READY) {
      client.setChannelLimit(channelLimit);
    }
    if (e.state == InitializationState.REMOTE_READY) {
      client.joinChannel(key);
    }
  });

  client.onSignalingStateChanged.listen((SignalingStateEvent e) {
    if (e.state == Signaler.SIGNALING_STATE_OPEN) {
      client.setChannelLimit(channelLimit);
    } else if (e.state == Signaler.SIGNALING_STATE_CLOSED){
      new Timer(const Duration(milliseconds: 10000), () {
        client.initialize();
      });
    }
  });

  client.onDataChannelStateChangeEvent.listen((DataChannelStateChangedEvent e) {
    if (e.state == DATACHANNEL_OPEN) {
      draw.addPeer(e.peerwrapper.id);
    } else if (e.state == DATACHANNEL_CLOSED) {
      draw.removePeer(e.peerwrapper.id);
    }
  });

  client.onBinaryEvent.listen((RtcEvent e) {
    if (e is BinaryBufferCompleteEvent) {
      BinaryBufferCompleteEvent bbc = e;

      Map m = json.parse(BinaryData.stringFromBuffer(bbc.buffer));
      if (m.containsKey('packetType')) {
        int packetType = m['packetType'];
        if (packetType == PeerPacket.TYPE_START_DRAW) {
          draw.startDraw(bbc.peer.id, StartDrawPacket.fromMap(m));
        } else if (packetType == PeerPacket.TYPE_UPDATE_DRAW) {
          draw.updateDraw(bbc.peer.id, UpdateDrawPacket.fromMap(m));
        } else if (packetType == PeerPacket.TYPE_END_DRAW) {
          draw.endDraw(bbc.peer.id, EndDrawPacket.fromMap(m));
        }
      }
    }
  });

  client.initialize();
}

class CanvasDraw {
  CanvasElement _element;
  CanvasRenderingContext2D _ctx;
  //List<DataPeerWrapper> _peerIds;
  Map<String, Point> _peerIds;
  PeerPacket _toSend;
  PeerClient _client;
  Timer _timer;
  static const int _updateInterval = 10;
  int _lastSent;
  bool _isMouseDown = false;
  Point _previous;

  CanvasDraw(CanvasElement c, PeerClient client) {
    _element = c;
    _element.width = 770;
    _element.height = 400;
    _ctx = c.context2D;
    _peerIds = new Map<String, Point>();

    _client = client;
    _lastSent = new DateTime.now().millisecondsSinceEpoch;
    //_timer = new Timer.periodic(const Duration(milliseconds: updateInterval), _onTick);
    _element.onMouseDown.listen(_onMouseDown);
    _element.onMouseMove.listen(_onMouseMove);
    _element.onMouseUp.listen(_onMouseUp);
    _element.onTouchStart.listen(_onTouchStart);
    _element.onTouchEnd.listen(_onTouchEnd);
    _element.onTouchMove.listen(_onTouchMove);
  }

  void addPeer(String id) {
    window.setImmediate(() {
      if (!_peerIds.containsKey(id))
        _peerIds[id] = null;
    });
  }

  void removePeer(String id) {
    window.setImmediate(() {
      if (_peerIds.containsKey(id))
        _peerIds.remove(id);
    });
  }

  void startDraw(String id, StartDrawPacket p) {

    _ctx.beginPath();
    _ctx.moveTo(p.x, p.y);
    _ctx.lineTo(p.x, p.y);
    _ctx.stroke();
    _peerIds[id] = new Point(p.x, p.y);
  }

  void updateDraw(String id, UpdateDrawPacket p) {
    Point previous = _peerIds[id];
    _ctx.beginPath();
    _ctx.moveTo(previous.x, previous.y);
    _ctx.lineTo(p.x, p.y);
    _ctx.stroke();
    _peerIds[id] = new Point(p.x, p.y);
  }

  void endDraw(String id, EndDrawPacket p) {

    _ctx.beginPath();
    _ctx.moveTo(p.x, p.y);
    _ctx.lineTo(p.x, p.y);
    _ctx.stroke();
    _peerIds[id] = new Point(p.x, p.y);
  }

  void _onTouchStart(TouchEvent e) {
    e.preventDefault();

    _isMouseDown = true;
    int x = e.targetTouches[0].page.x;
    int y = e.targetTouches[0].page.y;
    _ctx.beginPath();
    _ctx.moveTo(x, y);
    _ctx.lineTo(x, y);
    _ctx.stroke();
    _previous = new Point(x, y);
    _signalMouseDown(x, y);
  }

  void _onMouseDown(MouseEvent e) {
    _isMouseDown = true;

    _ctx.beginPath();
    _ctx.moveTo(e.offset.x, e.offset.y);
    _ctx.lineTo(e.offset.x, e.offset.y);
    _ctx.stroke();
    _previous = new Point(e.offset.x, e.offset.y);

    _signalMouseDown(e.offset.x, e.offset.y);
  }

  void _signalMouseDown(int x, int y) {
    _toSend = new StartDrawPacket(x, y);
    _peerIds.forEach((String id, Point p) {
      _client.sendByteBufferUnReliable(id, _toSend.toBuffer());
    });
  }

  void _onTouchEnd(TouchEvent e) {
    e.preventDefault();

    _isMouseDown = false;
    int x = e.targetTouches[0].page.x;
    int y = e.targetTouches[0].page.y;
    _ctx.beginPath();
    _ctx.moveTo(x, y);
    _ctx.lineTo(x, y);
    _ctx.stroke();
    _previous = new Point(x, y);
    _signalMouseUp(x, y);
  }

  void _onMouseUp(MouseEvent e) {
    _isMouseDown = false;

    _ctx.beginPath();
    _ctx.moveTo(e.offset.x, e.offset.y);
    _ctx.lineTo(e.offset.x, e.offset.y);
    _ctx.stroke();
    _previous = new Point(e.offset.x, e.offset.y);

    _signalMouseUp(e.offset.x, e.offset.y);
  }

  void _signalMouseUp(int x, int y) {
    _toSend = new EndDrawPacket(x, y);
    _peerIds.forEach((String id, Point p) {
      _client.sendByteBufferUnReliable(id, _toSend.toBuffer());
    });
  }

  void _onTouchMove(TouchEvent e) {
    if (!_isMouseDown)
      return;

    int x = e.targetTouches[0].page.x;
    int y = e.targetTouches[0].page.y;

    _ctx.beginPath();
    _ctx.moveTo(_previous.x, _previous.y);
    _ctx.lineTo(x, y);
    _ctx.stroke();
    _previous = new Point(x, y);

    int now = new DateTime.now().millisecondsSinceEpoch;
    if (now > _lastSent + _updateInterval) {
      _signalMouseMove(x, y);
      _lastSent = now;
    }
  }

  void _onMouseMove(MouseEvent e) {
    if (!_isMouseDown)
      return;

    _ctx.beginPath();
    _ctx.moveTo(_previous.x, _previous.y);
    _ctx.lineTo(e.offset.x, e.offset.y);
    _ctx.stroke();
    _previous = new Point(e.offset.x, e.offset.y);

    int now = new DateTime.now().millisecondsSinceEpoch;
    if (now > _lastSent + _updateInterval) {
      _signalMouseMove(e.offset.x, e.offset.y);
      _lastSent = now;
    }
  }

  void _signalMouseMove(int x, int y) {
    _toSend = new UpdateDrawPacket(x, y);
    _peerIds.forEach((String id, Point p) {
      _client.sendByteBufferUnReliable(id, _toSend.toBuffer());
    });
    //for (int i = 0; i < _peerIds.length; i++) {
    //  PeerWrapper pw = _peerIds[i];
    //  _client.sendArrayBufferReliable(pw.id, _toSend.toBuffer());
    //}
  }

  void _onTick(Timer t) {

  }
}

