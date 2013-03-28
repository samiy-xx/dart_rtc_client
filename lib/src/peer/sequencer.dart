part of rtc_client;

class Sequencer {
  List<SequenceCollection> _sequenceCollections;
  
  Sequencer() {
    _sequenceCollections = new List<SequenceCollection>();
  }
  
  List<SequenceCollection> getCollections() {
    return _sequenceCollections;
  }
  
  bool hasSequenceCollection(int signature) {
    for (int i = 0; i < _sequenceCollections.length; i++) {
      if (_sequenceCollections[i].signature == signature)
        return true;
    }
    return false;
  }
  
  SequenceCollection getSequenceCollection(int signature) {
    for (int i = 0; i < _sequenceCollections.length; i++) {
      if (_sequenceCollections[i].signature == signature)
        return _sequenceCollections[i];
    }
    return null;
  }
  
  bool hasSequence(int signature, int sequence) {
    var sequences = getSequenceCollection(signature);
    return sequences != null && sequences.hasEntry(sequence);
  }
  
  SequenceCollection createNewSequenceCollection(int signature, int size) {
    //new Logger().Debug("Creating new sequence collection of size $size for signature $signature");
    var sequences = getSequenceCollection(signature);
    if (sequences == null) {
      sequences = new SequenceCollection(signature, size);
      _sequenceCollections.add(sequences);
      //new Logger().Debug("Created new sequence collection of size $size for signature $signature");
    }
    return sequences;
  }
  
  void addSequence(int signature, int size, SequenceEntry se) {
    var sequences = getSequenceCollection(signature);
    if (sequences == null)
      sequences = createNewSequenceCollection(signature, size);
    
    sequences.setEntry(se);
  }
  
  void removeSequence(int signature, int sequence) {
    
    if (!hasSequence(signature, sequence))
      return;
    
    var sequences = getSequenceCollection(signature);
    if (sequences != null) {
      sequences.removeEntry(sequence);
    
      if (sequences.isEmpty)
        _sequenceCollections.remove(sequences);
    }
    
  }
  
  void clear() {
    _sequenceCollections.clear();  
  }
  
  bool hasMore() {
    return _sequenceCollections.length > 0;
  }
}

class SequenceCollection {
  int _signature;
  int _total;
  List<SequenceEntry> _sequences;
  
  bool get isComplete => _isComplete();
  bool get isEmpty => _isEmpty();
  int get total => _total;
  int get signature => _signature;
  List<SequenceEntry> get sequences => _sequences;
  
  SequenceCollection(int signature, int total) {
    _total = total;
    _signature = signature;
    _sequences = new List<SequenceEntry>(total);
  }
  
  SequenceEntry addCreateSequence(int sequence, ArrayBuffer buffer) {
    var se = new SequenceEntry(sequence, buffer);
    _sequences[sequence - 1] = se;
    return se;
  }
  
  void setEntry(SequenceEntry entry) {
    _sequences[entry.sequence - 1] = entry;
  }
  
  bool hasEntry(int sequence) {
    if (sequence > _total || sequence < 0)
      return false; 
    return _sequences[sequence - 1] != null;
  }
  
  bool _isComplete() {
    for (int i = 0; i < _total; i++) {
      if (_sequences[i] == null)
        return false;
    }
    return true;
  }
  
  bool _isEmpty() {
    for (int i = 0; i < _total; i++) {
      if (_sequences[i] != null)
        return false;
    }
    return true;
  }
  
  SequenceEntry getEntry(int sequence) {
    if (sequence > _total || sequence < 0)
      throw new RangeError("Attept to access array out of bounds");
     return _sequences[sequence - 1];
  }
  
  SequenceEntry removeEntry(int sequence) {
    if (sequence > _total || sequence < 0)
      throw new RangeError("Attept to access array out of bounds");
    
    SequenceEntry entry = _sequences[sequence - 1];
    if (entry != null) {
      _sequences[sequence - 1] = null;
    }
    return entry;
  }
  
  List<SequenceEntry> getFirstThree() {
    int count = _sequences.length > 2 ? 3 : _sequences.length;
    List<SequenceEntry> l = new List<SequenceEntry>(count);
    for (int i = 0; i < count; i++) {
      l[i] = _sequences[i];
    }
    return l;
  }
  
  SequenceEntry getFirst() {
    for (int i = 0; i < _sequences.length; i++) {
      if (_sequences[i] != null)
        return _sequences[i];
    }
    return null;
  }
  
  void clear() {
    for (int i = 0; i < _total; i++) {
      _sequences[i] = null;
    }
  }
  
  operator ==(Object o) {
    if (!(o is SequenceCollection))
      return false;
    
    SequenceCollection collection = o as SequenceCollection;
    return collection._signature == _signature;
  }
}

class SendSequenceEntry extends SequenceEntry {
  int timeStored;
  int timeSent;
  int timeReSent;
  bool resend;
  bool sent;
  
  SendSequenceEntry(int sequence, ArrayBuffer data) : super(sequence, data) {
    timeStored = new DateTime.now().millisecondsSinceEpoch;
    resend = true;
    sent = false;
  }
  
  void markSent() {
    sent = true;
    timeSent = new DateTime.now().millisecondsSinceEpoch;
    timeReSent = new DateTime.now().millisecondsSinceEpoch;
  }

  void markReSent() {
    timeReSent = new DateTime.now().millisecondsSinceEpoch;
  }
}

class SequenceEntry implements Comparable {
  int sequence;
  ArrayBuffer data;
  
  SequenceEntry(this.sequence, this.data);
  
  int compareTo(SequenceEntry o) {
    if (sequence < o.sequence)
      return -1;
    
    if (sequence == o.sequence)
      return 0;
    
    if (sequence > o.sequence)
      return 1;
  }
}