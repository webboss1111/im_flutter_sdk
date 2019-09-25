import 'package:flutter/services.dart';
import 'package:meta/meta.dart';

import 'dart:async';

import 'em_chat_manager.dart';
import 'em_contact_manager.dart';
import 'em_domain_terms.dart';
import 'em_log.dart';
import 'em_listeners.dart';
import 'em_sdk_method.dart';

class EMClient {
  static const _channelPrefix = 'com.easemob.im';
  static const MethodChannel _emClientChannel =
      const MethodChannel('$_channelPrefix/em_client');

  static final EMLog _log = EMLog();
  final EMChatManager _chatManager = EMChatManager(log: _log);
  final EMContactManager _contactManager = EMContactManager(log: _log);

  final _connectionListenerList = List<EMConnectionListener>();
  static EMClient _instance;

  /// instance fields
  String _currentUser;
  bool _loggedIn = false;
  bool _connected = false;
  EMOptions _options;

  factory EMClient.getInstance() {
    return _instance = _instance ?? EMClient._internal();
  }

  /// private constructor
  EMClient._internal() {
    _addNativeMethodCallHandler();
  }

  void _addNativeMethodCallHandler() {
    _emClientChannel.setMethodCallHandler((MethodCall call) {
      Map argMap = call.arguments;
      if (call.method == EMSDKMethod.onConnectionDidChanged) {
        _onConnectionChanged(argMap);
      }
      return;
    });
  }

  /// init - init Easemob SDK client with specified [options] instance.
  void init(EMOptions options) {
    _options = options;
    _emClientChannel.invokeMethod(EMSDKMethod.init, {"appkey": options.appKey});
  }

  /// createAccount - create an account with [userName]/[password].
  /// Callback [onError] once account creation failed.
  void createAccount(
      {@required String userName,
      @required String password,
      onError(int errorCode, String desc)}) {
    Future<Map> result = _emClientChannel.invokeMethod(
        EMSDKMethod.createAccount, {userName: userName, password: password});
    result.then((response) {
      if (!response['success']) {
        if (onError != null) onError(response['code'], response['desc']);
      }
    });
  }

  /// login - login server with [id]/[password].
  /// Call [onSuccess] once login succeed and [onError] error occured.
  void login(
      {@required String userName,
      @required String password,
      onSuccess(),
      onError(int errorCode, String desc)}) {
    Future<Map> result = _emClientChannel.invokeMethod(
        EMSDKMethod.login, {userName: userName, password: password});
    result.then((response) {
      if (response['success']) {
        _loggedIn = true;
        if (onSuccess != null) {
          // set current user name
          _currentUser = userName;
          onSuccess();
        }
      } else {
        if (onError != null) onError(response['code'], response['desc']);
      }
    });
  }

  /// loginWithToken - login with [userName] and [token].
  /// Call [onSuccess] once login succeed and [onError] error occured.
  void loginWithToken(
      {@required String userName,
      @required String token,
      onSuccess(),
      onError(int errorCode, String desc)}) {
    Future<Map> result = _emClientChannel
        .invokeMethod(EMSDKMethod.login, {userName: userName, token: token});
    result.then((response) {
      if (response['success']) {
        _loggedIn = true;
        if (onSuccess != null) onSuccess();
      } else {
        if (onError != null) onError(response['code'], response['desc']);
      }
    });
  }

  /// logout - log out synchronously.
  /// int logout(bool unbindToken){}

  /// logout - log out.
  /// if [unbindToken] is true, then invalidate the previous bound token.
  /// Call [onSuccess] once login succeed and [onError] error occured.
  void logout(
      {bool unbindToken = false, onSuccess(), onError(int code, String desc)}) {
    Future<Map> result = _emClientChannel
        .invokeMethod(EMSDKMethod.logout, {unbindToken: unbindToken});
    result.then((response) {
      if (response['success']) {
        _loggedIn = false;
      } else {
        if (onError != null) onError(response['code'], response['desc']);
      }
    });
  }

  /// changeAppKey - change app key with new [appKey].
  /// Call [onError] if something wrong.
  void changeAppkey({@required String appKey, onError(int code, String desc)}) {
    Future<Map> result = _emClientChannel
        .invokeMethod(EMSDKMethod.changeAppKey, {appKey: appKey});
    result.then((response) {
      if (!response['success']) {
        if (onError != null) onError(response['code'], response['desc']);
      }
    });
  }

  /// setDebugMode - set to run in debug mode.
  void setDebugMode(bool debugMode) {
    _emClientChannel
        .invokeMethod(EMSDKMethod.setDebugMode, {debugMode: debugMode});
  }

  /// updateCurrentUserNick - update user nick with [nickName].
  Future<bool> updateCurrentUserNick(String nickName) async {
    Map<String, dynamic> result = await _emClientChannel
        .invokeMethod(EMSDKMethod.updateCurrentUserNick, {nickName: nickName});
    if (result['success']) {
      return result['status'] as bool;
    } else {
      return false;
    }
  }

  void uploadLog({onSuccess(), onError(int code, String desc)}) {
    Future<Map> result = _emClientChannel.invokeMethod(EMSDKMethod.uploadLog);
    result.then((response) {
      if (response['success']) {
        if (onSuccess != null) {
          onSuccess();
        } else {
          if (onError != null) {
            onError(response['code'], response['desc']);
          }
        }
      }
    });
  }

  /// getOptions - return [EMOptions] inited.
  EMOptions getOptions() {
    return _options;
  }

  Future<String> compressLogs(onError(int code, String desc)) async {
    Map<String, dynamic> result =
        await _emClientChannel.invokeMethod(EMSDKMethod.compressLogs);
    if (result['success']) {
      return result['logs'] as String;
    } else {
      if (onError != null) onError(result['code'], result['desc']);
      return '';
    }
  }

  /// getLoggedInDevicesFromServer - return all logged in devices.
  /// Access controlled by [userName]/[password] and if error occured,
  /// [onError] is called.
  Future<List<EMDeviceInfo>> getLoggedInDevicesFromServer(
      {@required String userName,
      @required String password,
      onError(int code, String desc)}) async {
    Map<String, dynamic> result = await _emClientChannel.invokeMethod(
        EMSDKMethod.getLoggedInDevicesFromServer,
        {userName: userName, password: password});
    if (result['success']) {
      return _convertDeviceList(result['devices']);
    } else {
      if (onError != null) onError(result['code'], result['desc']);
      return null;
    }
  }

  List<EMDeviceInfo> _convertDeviceList(List deviceList) {
    var result = List<EMDeviceInfo>();
    for (var device in deviceList) {
      result.add(
          EMDeviceInfo(device['resource'], device['UUID'], device['name']));
    }
    return result;
  }

  /// getCurrentUser - get current user name.
  /// Return null if not successfully login IM server yet.
  String getCurrentUser() {
    return _currentUser;
  }

  /// getUserTokenFromServer - get token from server with specified [userName]/[password].
  /// Returned token set in [onSuccess] callback and [onError] called once error occured.
  void getUserTokenFromServer(
      {@required final String userName,
      @required final String password,
      onSuccess(String token),
      onError(int code, String desc)}) {
    Future<Map> result = _emClientChannel.invokeMethod(
        EMSDKMethod.login, {userName: userName, password: password});
    result.then((response) {
      if (!response['success']) {
        if (onSuccess != null) onSuccess(response['token']);
      } else {
        if (onError != null) onError(response['code'], response['desc']);
      }
    });
  }

  /// isLoggedInBefore - whether successful login invoked before.
  bool isLoggedInBefore() {
    return _loggedIn;
  }

  /// isConnected - whether connection connected now.
  bool isConnected() {
    return _connected;
  }

  /// addConnectionListener - set listeners for connected/disconnected events.
  void addConnectionListener(EMConnectionListener listener) {
    assert(listener != null);
    _connectionListenerList.add(listener);
  }

  /// removeConnectionListener - get rid of listener from receiving connection events.
  void removeConnectionListener(EMConnectionListener listener) {
    assert(listener != null);
    _connectionListenerList.remove(listener);
  }

  /// once connection changed, listeners to be informed.
  void _onConnectionChanged(Map map) {
    bool isConnected = map["isConnected"];
    for (var listener in _connectionListenerList) {
      // TODO: to inform listners asynchronously
      if (isConnected) {
        _connected = true;
        listener.onConnected();
      } else {
        _connected = false;
        listener.onDisconnected();
      }
    }
  }

  /// chatManager - retrieve [EMChatManager] handle.
  EMChatManager chatManager() {
    return _chatManager;
  }

  /// contactManager - retrieve [EMContactManager] handle.
  EMContactManager contactManager() {
    return _contactManager;
  }
}
