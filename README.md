dart_rtc_client
========

Dart WebRTC client library and api
--------

Do note that this library is in no way stable at the moment.   
Things will go bang! and also Here be dragons!   

## Sample ##

```dart
import 'dart:html';
import 'package:dart_rtc_client/rtc_client.dart';
 
const int RECONNECT_MS = 10000;
const String MYCHANNEL = "abc";
const String CONNECTION_STRING = "ws://127.0.0.1:8234/ws";
 
/**
 * WebRTC video "conference" sample
 */
void main() {
 
  /**
   * DataSource connects to the signaling server
   */
  DataSource src = new WebSocketDataSource(CONNECTION_STRING);
 
  /**
   * ChannelClient accepts on parameter, which is the data source.
   */
  ChannelClient client = new ChannelClient(src)
  //.setChannel(MYCHANNEL) // Setting channel here sets the client to join the channel on connect
  .setRequireAudio(true) // Microphone required
  .setRequireVideo(true) // Webcam or some other video source required
  .setRequireDataChannel(false) // Set true if you want to send data over data channels
  .setAutoCreatePeer(true); // If true, creates peerconnection automicly when joining a channel
 
  /**
   * Client sets states, in this callback you can track the state changes
   * and do actions when required
   */
  client.onInitializationStateChangeEvent.listen((InitializationStateEvent e) {
    if (e.state == InitializationState.LOCAL_READY) {
      // Client has initialized local, not connected to the signaling server yet.
    }
 
    if (e.state == InitializationState.MEDIA_READY) {
      // Your local video stream is ready
    }
 
    if (e.state == InitializationState.REMOTE_READY) {
      // If you did not use .setChannel above, this is where you can join channel (Or later on if you so wish)
      client.joinChannel(MYCHANNEL);
    }
 
    if (e.state == InitializationState.CHANNEL_READY) {
      // Channel has been joined.
      // Setting channel limit to 2, which means that only 2 persons are able to join the channel.
      client.setChannelLimit(2);
    }
  });
 
  /**
   * Client has connected to the server
   */
  client.onSignalingOpenEvent.listen((SignalingOpenEvent e) {
 
  });
 
  /**
   * MediaStream available events
   * Event name subject to change to onMediaStreamAvailableEvent
   * since this carries also local media stream event
   */
  client.onRemoteMediaStreamAvailableEvent.listen((MediaStreamAvailableEvent e) {
    // Event contains a reference to PeerWrapper (e.peerWrapper) which has an id property
    // Usefull for tracking created video elements for example.
    // set the video element id to peerwrapper id.
 
    if (e.isLocal) {
      LocalMediaStream localStream = e.stream;
      // Do what is needed with your local media stream
      // someVideoElement.src = Url.createObjectUrl(localStream);
      // someVideoElement.play();
    } else {
      MediaStream remoteStream = e.stream;
      // Do what is needed with your local media stream
      // someOtherVideoElement.src = Url.createObjectUrl(remoteStream);
      // someOtherVideoElement.play();
    }
  });
 
  /**
   * MediaStream removed events
   */
  client.onRemoteMediaStreamRemovedEvent.listen((MediaStreamRemovedEvent e) {
    // Remove the video element created earlier
    // If you used the e.peerWrapper.id as an id to the video element
    // you can use that again to find the element and remove it.
  });
 
  /**
   * Callback for when you loose connection to the server
   */
  client.onSignalingCloseEvent.listen((SignalingCloseEvent e) {
    window.setTimeout(() {
      client.initialize();
    }, RECONNECT_MS);
  });
 
  client.initialize();
}

```

[![Build Status](https://drone.io/github.com/samiy-xx/dart_rtc_client/status.png)](https://drone.io/github.com/samiy-xx/dart_rtc_client/latest)

[![githalytics.com alpha](https://cruel-carlota.pagodabox.com/e2f8d6045c2d3663c561fe923007f1df "githalytics.com")](http://githalytics.com/samiy-xx/dart-rtc.git)
