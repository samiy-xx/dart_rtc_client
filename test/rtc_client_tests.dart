library rtc_client_tests;

import 'dart:html';
import '../packages/unittest/unittest.dart';
import '../packages/unittest/html_enhanced_config.dart';
import '../packages/unittest/html_config.dart';
import '../packages/unittest/mock.dart';
import '../lib/rtc_client.dart';
import 'package:dart_rtc_common/rtc_common.dart';

part 'mocks/chunksender.dart';
part 'mocks/binaryeventlistener.dart';

part 'tests/binarytests.dart';
part 'tests/binarywritertests.dart';
part 'tests/binaryreadertests.dart';
part 'tests/rtttests.dart';
part 'tests/sequencertests.dart';

void run() {
  useHtmlEnhancedConfiguration();
  //useHtmlConfiguration();
  new BinaryTests().run();
  new BinaryWriterTests().run();
  new BinaryReaderTests().run();
  new RoundTripTimerTests().run();
  new SequencerTests().run();
}