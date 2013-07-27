import "dart:html";
import "dart:async";
import 'dart:json' as json;
import 'dart:typed_data';
import '../lib/rtc_client.dart';
import 'peerpacket.dart';

void main() {
  List<Blob> _blobParts = new List<Blob>();
  final String key = query("#key").text;
  DivElement album = query("#album");
  DivElement application = query("#application");
  ProgressElement progress = query("#progress_bar");
  progress.style.width = "${application.clientWidth - 10}px";
  progress.style.display = "none";

  String currentFileName;
  int currentFileSize;
  int received = 0;
  AlbumCanvas ac = new AlbumCanvas(query("#albumcanvas"));
  Thumbnailer thumb = new Thumbnailer();
  thumb.setCanvasHeight(30);
  thumb.setCanvasWidth(50);

  List<String> peers = new List<String>();
  final int channelLimit = 10;

  PeerClient client = new PeerClient(new WebSocketDataSource("ws://127.0.0.1:8234/ws"))
  .setRequireAudio(Browser.isFirefox)
  .setRequireVideo(false)
  .setRequireDataChannel(true)
  .setAutoCreatePeer(true);

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
      if (!peers.contains(e.peerwrapper.id))
        peers.add(e.peerwrapper.id);
    } else if (e.state == DATACHANNEL_CLOSED) {
      window.setImmediate(() {
        if (peers.contains(e.peerwrapper.id))
          peers.remove(e.peerwrapper.id);
      });
    }
  });

  client.onBinaryEvent.listen((RtcEvent e) {
    if (e is BinaryBufferCompleteEvent) {
      BinaryBufferCompleteEvent bbc = e;
      Map m = json.parse(BinaryData.stringFromBuffer(bbc.buffer));
      if (m.containsKey('packetType')) {
        int packetType = m['packetType'];
        if (packetType == PeerPacket.TYPE_RECEIVE_FILENAME) {
          currentFileName = FileNamePacket.fromMap(m).fileName;
          currentFileSize = FileNamePacket.fromMap(m).fileSize;
          received = 0;
          _blobParts.clear();
        }
      }
    }

    else if (e is BinaryFileCompleteEvent) {
      BinaryFileCompleteEvent bfce = e;
      ac.setImageFromBlob(bfce.blob).then((ImageElement img) {
        String oUrl = Url.createObjectUrl(bfce.blob);

        ImageElement thumbImg = new ImageElement();
        thumbImg.onLoad.listen((Event e) {
          query("#files").append(buildEntry(thumbImg, currentFileName, oUrl));
        });
        thumbImg.src = thumb.getDataUrl(img);

        new Timer(const Duration(milliseconds: 2000), () {
          progress.style.display = "none";
        });
      });
    }

    if (e is BinaryBlobChunk) {
      BinaryBlobChunk chunk = e;
      _blobParts.add(chunk.blob);

      received += chunk.blob.size;
      if (received == currentFileSize) {
        Blob b = new Blob(_blobParts);
        ac.setImageFromBlob(b).then((ImageElement img) {
          String oUrl = Url.createObjectUrl(b);

          ImageElement thumbImg = new ImageElement();
          thumbImg.onLoad.listen((Event e) {
            query("#files").append(buildEntry(thumbImg, currentFileName, oUrl));
          });
          thumbImg.src = thumb.getDataUrl(img);

          new Timer(const Duration(milliseconds: 2000), () {
            progress.style.display = "none";
          });
        });
      }
    }

    else if (e is BinaryChunkEvent) {
      BinaryChunkEvent bce = e;

      if (progress.style.display == "none")
        progress.style.display = "block";
      progress.max = bce.totalSequences;
      progress.value = bce.sequence;
    }

    else if (e is BinaryChunkWriteEvent) {
      BinaryChunkWriteEvent bcwrite = e;

    }

    else if (e is BinaryChunkWroteEvent) {
      BinaryChunkWroteEvent bcwrote = e;

      if (progress.style.display == "none")
        progress.style.display = "block";
      progress.max = bcwrote.totalSequences;
      progress.value = bcwrote.sequence;
    }

  });

  FileUploadInputElement fuie = new FileUploadInputElement();
  fuie.accept ="image/*";
  Element openFileButton = query("#addButton");
  openFileButton.onClick.listen((Event e) => fuie.click());

  FileReader reader = new FileReader();

  fuie.onChange.listen((Event e) {
    for (int i = 0; i < fuie.files.length; i++) {
      File file = fuie.files[i];
      currentFileName = file.name;
      currentFileSize = file.size;
      peers.forEach((String id) {
        client.sendByteBufferReliable(id, new FileNamePacket(currentFileName, currentFileSize).toBuffer()).then((int i) {
          client.sendFile(id, file).then((int i) {
            int seconds = i > 0 ? i ~/ 1000 : 0;
            print("Sent image to id $id in $seconds seconds");
            new Timer(const Duration(milliseconds: 2000), () {
              progress.style.display = "none";
            });
          });
        });
      });
      reader.readAsArrayBuffer(file);
    }
  });

  reader.onLoadEnd.listen((ProgressEvent e) {
    ByteBuffer data = reader.result;
    //print("read buffer");
    //peers.forEach((String id) {
    //  client.sendByteBufferReliable(id, new FileNamePacket(currentFileName).toBuffer()).then((int i) {
    //    client.sendFile(id, data).then((int i) {
    //      int seconds = i > 0 ? i ~/ 1000 : 0;
    //      print("Sent image to id $id in $seconds seconds");
    //      new Timer(const Duration(milliseconds: 2000), () {
    //        progress.style.display = "none";
    //      });
    //    });
    //  });
    //});
    ac.setImageFromBuffer(data);
  });

  client.initialize();
}

DivElement buildEntry(ImageElement img, String fileName, String url) {
  DivElement entry = new DivElement();
  entry.classes.add("fileEntry");

  SpanElement imgSpan = new SpanElement();
  imgSpan.append(img);
  imgSpan.classes.add("imgSpan");

  AnchorElement link = new AnchorElement();
  link.text = fileName;
  link.href = url;
  link.download = fileName;

  SpanElement fileNameSpan = new SpanElement();
  fileNameSpan.append(link);
  fileNameSpan.classes.add("fileNameSpan");

  entry.append(imgSpan);
  entry.append(fileNameSpan);

  return entry;
}

class CanvasThingy {
  CanvasElement _canvas;
  CanvasRenderingContext2D _ctx;
  CanvasElement get canvas => _canvas;
  CanvasThingy() {
    _canvas = new CanvasElement();
    _ctx = _canvas.context2d;
  }
}

class FullsizeNailer extends CanvasThingy {
  FullsizeNailer() : super();
  String getDataUrl(ImageElement img) {
    _ctx.drawImageScaled(img, 0, 0, img.width, img.height);
    return _canvas.toDataUrl("image/png");
  }
}

class Thumbnailer extends CanvasThingy {
  int _canvasWidth = 300;
  int _canvasHeight = 200;
  set width(int w) => setCanvasWidth(w);
  set Height(int h) => _canvasHeight = h;

  Thumbnailer() : super();

  void setCanvasWidth(int w) {
    _canvas.width = w;
    _canvasWidth = w;
  }

  void setCanvasHeight(int h) {
    _canvas.height = h;
    _canvasHeight = h;
  }

  String getDataUrl(ImageElement img) {
    _ctx.drawImageScaled(img, 0, 0, _canvasWidth, _canvasHeight);
    return _canvas.toDataUrl("image/png");
  }
}

class AlbumCanvas {
  static const int CANVAS_WIDTH = 800;
  static const int CANVAS_HEIGHT = 500;
  CanvasElement _canvas;
  CanvasRenderingContext2D _ctx;

  AlbumCanvas(CanvasElement c) {
    _canvas = c;
    _ctx = c.context2d;
    _canvas.height = CANVAS_HEIGHT;
    _canvas.width = getWidth();
  }

  int getWidth() {
    int w = _canvas.parent.clientWidth;

    return w;
  }

  Future<ImageElement> setImageFromBuffer(ByteBuffer buffer) {
    return _setImageFromUrl(Url.createObjectUrl(new Blob([buffer])));
  }

  Future<ImageElement> setImageFromBlob(Blob blob) {
    return _setImageFromUrl(Url.createObjectUrl(blob));
  }

  Future<ImageElement>_setImageFromUrl(String url) {
    Completer<ImageElement> completer = new Completer<ImageElement>();
    ImageElement img = new ImageElement();
    img.onLoad.listen((Event e) {
      _clear();
      if (img.height >= img.width) {
        _ctx.drawImageScaled(img, 0, 0, img.width * (_canvas.height/img.height), _canvas.height);
      } else {
        _ctx.drawImageScaled(img, 0, 0, _canvas.width, img.height * (_canvas.width/img.width));
      }
      Url.revokeObjectUrl(url);
      completer.complete(img);
    });
    img.src = url;
    return completer.future;
  }

  void _clear() {
    _ctx.clearRect(0, 0, _canvas.width, _canvas.height);
  }
}
