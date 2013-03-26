part of rtc_client_tests;

class SequencerTests {
  int defaultSignature = 111;
  int defaultSize = 10;
  
  run() {
    group('SequencerTests', () {
      
      Sequencer sequencer;
      
      setUp(() {
        sequencer = new Sequencer();
      });

      tearDown(() {
        sequencer = null;
      });
      
      test("Sequencer, When created, is not null", () {
        expect(sequencer, isNotNull);
      });
      
      test("Sequencer, When created, has an list for sequence collections", () {
        expect(sequencer.getCollections(), isNotNull);
        expect(sequencer.getCollections().length, equals(0));
      });
      
      test("Sequencer, calling create, adds a collection with defined signature and size", () {
        expect(sequencer.getCollections().length, equals(0));
        sequencer.createNewSequenceCollection(defaultSignature, defaultSize);
        expect(sequencer.getCollections().length, equals(1));
        SequenceCollection sc = sequencer.getCollections()[0];
        expect(sc.sequences.length, equals(defaultSize));
        expect(sc.total, equals(defaultSize));
        expect(sc.signature, equals(defaultSignature));
      });
      
      test("Sequencer, calling create multiple times, does not add duplicates", () {
        expect(sequencer.getCollections().length, equals(0));
        sequencer.createNewSequenceCollection(defaultSignature, defaultSize);
        sequencer.createNewSequenceCollection(defaultSignature, defaultSize);
        sequencer.createNewSequenceCollection(defaultSignature, defaultSize);
        expect(sequencer.getCollections().length, equals(1));
      });
      
      test("Sequencer, hasSequenceCollection, returns true if collection with defined signature is found", () {
        expect(sequencer.hasSequenceCollection(defaultSignature), equals(false));
        SequenceCollection sc = sequencer.createNewSequenceCollection(defaultSignature, defaultSize);
        expect(sequencer.hasSequenceCollection(defaultSignature), equals(true));
      });
      
      test("Sequencer, getSequenceCollection, returns collection with defined signature", () {
        expect(sequencer.getSequenceCollection(defaultSignature), equals(null));
        SequenceCollection sc = sequencer.createNewSequenceCollection(defaultSignature, defaultSize);
        expect(sequencer.getSequenceCollection(defaultSignature), equals(sc));
      });
      
      test("Sequencer, hasMore, returns true if collections count is larger than 0", () {
        SequenceCollection sc = sequencer.createNewSequenceCollection(defaultSignature, defaultSize);
        expect(sequencer.hasMore(), equals(true));
        sequencer.clear();
        expect(sequencer.hasMore(), equals(false));
      });
      
      test("Sequencer, hasSequence, returns true if sequence is found", () {
        SequenceCollection sc = sequencer.createNewSequenceCollection(defaultSignature, defaultSize);
        SequenceEntry se = new SequenceEntry(1, null);
        sc.setEntry(se);
        expect(sequencer.hasSequence(defaultSignature, 1), equals(true));
        expect(sequencer.hasSequence(defaultSignature, 2), equals(false));
      });
      
      test("Sequencer, calling clear, clears the collections", () {
        expect(sequencer.getCollections().length, equals(0));
        sequencer.createNewSequenceCollection(defaultSignature, defaultSize);
        expect(sequencer.getCollections().length, equals(1));
        sequencer.clear();
        expect(sequencer.getCollections().length, equals(0));
      });
      
      test("Sequencer, adding an sequence entry, creates a collection and adds the entry to the collection", () {
        sequencer.createNewSequenceCollection(defaultSignature, defaultSize);
        expect(sequencer.getCollections().length, equals(1));
        SequenceCollection sc = sequencer.getCollections()[0];
        
        SequenceEntry se = new SequenceEntry(1, null);
        sequencer.addSequence(defaultSignature, defaultSize, se);
        expect(sequencer.getCollections().length, equals(1));
        expect(sc.getFirst(), equals(se));
      });
      
      test("Sequencer, calling create, adds a collection", () {
        expect(sequencer.getCollections().length, equals(0));
        sequencer.createNewSequenceCollection(defaultSignature, defaultSize);
        expect(sequencer.getCollections().length, equals(1));
      });
      
      test("Sequencer, calling remove, removes a collection", () {
        expect(sequencer.getCollections().length, equals(0));
        SequenceCollection sc = sequencer.createNewSequenceCollection(defaultSignature, defaultSize);
        expect(sequencer.getCollections().length, equals(1));
        expect(sequencer.getCollections()[0], equals(sc));
        sc.addCreateSequence(1, null);
        sc.addCreateSequence(2, null);
        sequencer.removeSequence(defaultSignature, 1);
        expect(sequencer.getCollections().length, equals(1));
        sequencer.removeSequence(defaultSignature, 2);
        expect(sequencer.getCollections().length, equals(0));
      });
    });
    
    group('SequenceCollectionTests', () {
      SequenceCollection collection;
      
      setUp(() {
        collection = new SequenceCollection(defaultSignature, defaultSize);
      });

      tearDown(() {
        collection = null;
      });
      
      test("SequenceCollection, when created, is not null", () {
        expect(collection, isNotNull);
      });
      
      test("SequenceCollection, when created, has properties", () {
        expect(collection.isComplete, equals(false));
        expect(collection.isEmpty, equals(true));
        expect(collection.total, equals(defaultSize));
        expect(collection.signature, equals(defaultSignature));
        expect(collection.sequences.length, equals(defaultSize));
      });
      
      test("SequenceCollection, adding entry, succeeds", () {
        SequenceEntry se1 = new SequenceEntry(1, null);
        SequenceEntry se2 = new SequenceEntry(2, null);
        SequenceEntry se3 = new SequenceEntry(3, null);
        
        collection.setEntry(se1);
        collection.setEntry(se2);
        collection.setEntry(se3);
        
        expect(collection.sequences.length, equals(defaultSize));
        expect(collection.sequences[0], equals(se1));
        expect(collection.sequences[1], equals(se2));
        expect(collection.sequences[2], equals(se3));
        expect(collection.sequences[3], equals(null));
      });
      
      test("SequenceCollection, addCreateSequence, creates new entry", () {
        collection.addCreateSequence(1, null);
        expect(collection.sequences[0], isNotNull);
        expect(collection.sequences[0] is SequenceEntry, equals(true));
      });
      
      test("SequenceCollection, hasEntry, returns true if sequence exists", () {
        expect(collection.hasEntry(1), equals(false));
        collection.addCreateSequence(1, null);
        expect(collection.hasEntry(1), equals(true));
      });
      
      test("SequenceCollection, getEntry, returns sequence if sequence exists", () {
        expect(collection.getEntry(1), equals(null));
        collection.addCreateSequence(1, null);
        expect(collection.getEntry(1), equals(collection.sequences[0]));
      });
      
      test("SequenceCollection, getEntry, throws", () {
        try {
          expect(collection.getEntry(-1), throwsRangeError);
          expect(collection.getEntry(defaultSize + 1), throwsRangeError);
        } on RangeError catch(e) {}
      });
      
      test("SequenceCollection, removeEntry, removes entry from collection", () {
        expect(collection.getEntry(1), equals(null));
        collection.addCreateSequence(1, null);
        expect(collection.getEntry(1), equals(collection.sequences[0]));
        collection.removeEntry(1);
        expect(collection.getEntry(1), equals(null));
      });
      
      test("SequenceCollection, removeEntry, throws", () {
        try {
          expect(collection.removeEntry(-1), throwsRangeError);
          expect(collection.removeEntry(defaultSize + 1), throwsRangeError);
        } on RangeError catch(e) {}
      });
      
      test("SequenceCollection, getFirst, returns first non null entry", () {
        SequenceEntry se1 = new SequenceEntry(1, null);
        SequenceEntry se2 = new SequenceEntry(5, null);
        SequenceEntry se3 = new SequenceEntry(7, null);
        
        collection.setEntry(se1);
        collection.setEntry(se2);
        collection.setEntry(se3);
        
        expect(collection.getFirst(), equals(se1));
        collection.removeEntry(1);
        expect(collection.getFirst(), equals(se2));
      });
      
      test("SequenceCollection, when full, returns true on isComplete", () {
        expect(collection.isComplete, equals(false));
        for (int i = 0; i < defaultSize; i++) {
          collection.addCreateSequence(i + 1, null);
        }
        expect(collection.isComplete, equals(true));
      });
      
      test("SequenceCollection, when empty, returns true on isEmpty", () {
        collection.addCreateSequence(2, null);
        collection.addCreateSequence(1, null);
        expect(collection.isEmpty, equals(false));
        collection.clear();
        expect(collection.isEmpty, equals(true));
      });
      
      test("SequenceCollection, hasEntry, returns true if entry exists", () {
        collection.addCreateSequence(2, null);
        collection.addCreateSequence(1, null);
        expect(collection.hasEntry(1), equals(true));
        expect(collection.hasEntry(2), equals(true));
        expect(collection.hasEntry(3), equals(false));
      });
    });
  }
}

