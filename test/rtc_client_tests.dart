library rtc_client_tests;

import 'dart:html';
import 'dart:typed_data';
import 'dart:math';
import 'dart:async';

import '../packages/unittest/unittest.dart';
import '../packages/unittest/html_enhanced_config.dart';
import '../packages/unittest/html_config.dart';
import '../packages/unittest/mock.dart';
import '../lib/rtc_client.dart';
import 'package:dart_rtc_common/rtc_common.dart';

part 'mocks/binaryeventlistener.dart';
part 'mocks/mockudpwriter.dart';
part 'mocks/mocktcpwriter.dart';
part 'mocks/mocktcpreader.dart';

part 'tests/binarytests.dart';
part 'tests/binarywritertests.dart';
part 'tests/binaryreadertests.dart';
part 'tests/rtttests.dart';
part 'tests/sequencertests.dart';
part 'tests/udpreadertests.dart';
part 'tests/tcpreadertests.dart';
part 'tests/udpwritertests.dart';
part 'tests/tcpwritertests.dart';
part 'tests/testutils.dart';

void run() {
  useHtmlEnhancedConfiguration();
  new BinaryTests().run();
  //new RoundTripTimerTests().run();
  new SequencerTests().run();
  new UDPReaderTests().run();
  new TcpReaderTests().run();
  new TcpWriterTests().run();
  new UdpWriterTests().run();
}