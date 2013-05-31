part of rtc_client;

class Util {
  static RtcSessionDescription hackTheSdp(RtcSessionDescription sd) {
    String replaced = sd.sdp.replaceFirst("b=AS:30", "b=AS:1638400");
    RtcSessionDescription newSdp = new RtcSessionDescription({
      'sdp':replaced,
      'type':sd.type
    });
    return newSdp;
  }
}