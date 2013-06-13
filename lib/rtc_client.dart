library rtc_client;

import 'dart:html';
import 'dart:json' as json;
import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:logging/logging.dart';
import 'package:logging_handlers/logging_handlers_shared.dart';
import 'package:dart_rtc_common/rtc_common.dart';
//import '../../dart_rtc_common/lib/rtc_common.dart';

part 'src/peer/peermanager.dart';
part 'src/peer/peerconnection.dart';
part 'src/peer/sctppeerconnection.dart';
part 'src/peer/tmppeerconnection.dart';
part 'src/peer/binarydata.dart';
part 'src/peer/binaryreadstate.dart';
part 'src/peer/rtt.dart';
part 'src/peer/peerstate.dart';
part 'src/peer/sequencer.dart';

part 'src/peer/readers/binarydatareader.dart';
part 'src/peer/readers/udpdatareader.dart';
part 'src/peer/readers/bytebufferreader.dart';
part 'src/peer/readers/blobreader.dart';
part 'src/peer/readers/stringreader.dart';

part 'src/peer/writers/binarydatawriter.dart';
part 'src/peer/writers/bytebufferwriter.dart';
part 'src/peer/writers/udpdatawriter.dart';
part 'src/peer/writers/blobwriter.dart';
part 'src/peer/writers/stringwriter.dart';

part 'src/event/peereventlistener.dart';
part 'src/event/signalingeventlistener.dart';
part 'src/event/datasourceeventlistener.dart';
part 'src/event/binarydataeventlistener.dart';
part 'src/event/rtcevent.dart';
part 'src/event/mediastreamevent.dart';
part 'src/event/signalingevent.dart';
part 'src/event/peerevent.dart';
part 'src/event/datasourceevent.dart';
part 'src/event/initializationevent.dart';
part 'src/event/packetevent.dart';
part 'src/event/binaryevent.dart';
part 'src/event/serverevent.dart';

part 'src/signaling/signaler.dart';
part 'src/signaling/simplesignalhandler.dart';

part 'src/util/constraints.dart';
part 'src/util/peerconstraints.dart';
part 'src/util/streamconstraints.dart';
part 'src/util/videoconstraints.dart';
part 'src/util/serverconstraints.dart';
part 'src/util/util.dart';
part 'src/util/browser.dart';
part 'src/datasource/datasource.dart';
part 'src/datasource/websocketdatasource.dart';

part 'src/exception/notimplementedexception.dart';
part 'src/exception/wrapperexceptions.dart';

part 'api/rtcclient.dart';
part 'api/peerclient.dart';

final Logger libLogger = new Logger("dart_rtc_client");

/*const int CLOSE_NORMAL = 1000;
const int CLOSE_GOING_AWAY = 1001;
const int CLOSE_PROTOCOL_ERROR = 1002;
const int CLOSE_UNSUPPORTED = 1003;
const int RESERVED = 1004;
const int NO_STATUS = 1005;
const int ABNORMAL_CLOSE = 1006;
const int DATA_NOT_CONSISTENT = 1007;
const int POLICY_VIOLATION = 1008;
const int MESSAGE_TOO_LARGE = 1009;
const int NEGOTIATIONS_FAILED = 1010;
const int UNEXPECTED_CONDITION = 1011;
const int HANDSHAKE_FAILURE = 1015;*/

const bool DEBUG = true;
String WEBSOCKET_SERVER = DEBUG
    ? "ws://127.0.0.1:8234/ws"
    : "ws://bananafarm.org:8234/ws";
typedef void PeerMediaEventListenerType(MediaStream ms, String id, bool main);