part of rtc_client;

abstract class ServerEvent {

}

class ServerJoinEvent extends ServerEvent {
  String channel;
  bool isOwner;
  int limit;

  ServerJoinEvent(this.channel, this.isOwner, this.limit);
}

class ServerParticipantJoinEvent extends ServerEvent {
  String id;
  String channel;

  ServerParticipantJoinEvent(this.id, this.channel);
}

class ServerParticipantIdEvent extends ServerEvent {
  String id;
  String channel;

  ServerParticipantIdEvent(this.id, this.channel);
}

class ServerParticipantLeftEvent extends ServerEvent {
  String id;

  ServerParticipantLeftEvent(this.id);
}

class ServerParticipantStatusEvent extends ServerEvent {
  String id;
  String newId;

  ServerParticipantStatusEvent(this.id, this.newId);
}

class ServerChannelMessageEvent extends ServerEvent {
  String id;
  String channel;
  String message;
  ServerChannelMessageEvent(this.id, this.channel, this.message);
}

class ServerIceEvent extends ServerEvent {
  String id;
  RtcIceCandidate candidate;

  ServerIceEvent(this.id, this.candidate);
}

class ServerSessionDescriptionEvent extends ServerEvent {
  String id;
  RtcSessionDescription description;

  ServerSessionDescriptionEvent(this.id, this.description);
}