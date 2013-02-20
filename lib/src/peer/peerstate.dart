part of rtc_client;

/**
 * There is no offer­answer exchange in progress.
 * This is also the initial state in which case the local and remote descriptions are empty.
 */
const String PEER_STABLE = "stable";

/**
 * A local description, of type "offer", has been supplied.
 */
const String PEER_HAVE_LOCAL_OFFER = "have-local-offer";

/**
 * A remote description, of type "offer", has been supplied.
 */
const String PEER_HAVE_REMOTE_OFFER = "have-remote-offer";

/**
 * A remote description of type "offer" has been supplied and a local
 * description of type "pranswer" has been supplied.
 */
const String PEER_HAVE_LOCAL_PRANSWER = "have-local-pranswer";

/**
 * A local description of type "offer" has been supplied and a 
 * remote description of type "pranswer" has been supplied.
 */
const String PEER_HAVE_REMOTE_PRANSWER = "have-remote-pranswer";

/**
 * The connection is closed.
 */
const String PEER_CLOSED = "closed";

