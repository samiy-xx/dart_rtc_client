part of rtc_client_tests;

class BinaryTests {
  run() {
    group('BinaryTests', () {
      

      setUp(() {
        
      });

      tearDown(() {
        
      });

      
      test("BinaryData, Converter, can create array buffer from string", () {
        String testString = "this is a string";
        ArrayBuffer result = BinaryData.bufferFromString(testString);
        expect(result.byteLength, equals(testString.length));
      });
      
      test("BinaryData, Converter, can create string from buffer", () {
        String testString = "this is a string";
        ArrayBuffer result = BinaryData.bufferFromString(testString);
        expect(result.byteLength, equals(testString.length));
        String reCreated = BinaryData.stringFromBuffer(result);
        expect(reCreated, equals(testString));
      });
      
    });
  }
}

