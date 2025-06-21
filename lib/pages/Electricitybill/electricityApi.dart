import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:superhut/utils/hut_user_api.dart';

class ElectricityApi {
  var hutApi = HutUserApi();
  late List openids;
  late String openid, JSESSIONID;
  late String token;
  late String username;
  final dio = Dio();

  //基础电费信息设置
  late String factorycode, areaid, roomid, buildingid;

  //初始化API
  onInit() async {
    openids = await hutApi.getOpenid();
    openid = openids[0];
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString('hutToken') != null) {
      //bool isv =await refreshToken();
      token = prefs.getString('hutToken')!;
    }
    JSESSIONID = openids[1];
    await getUserInfo();
    configureHutDio();
    print(openids[0]);
  }

  Future<void> configureHutDio() async {
    // Update default configs.
    dio.options.baseUrl = 'https://v8mobile.hut.edu.cn';
    dio.options.connectTimeout = Duration(seconds: 5);
    dio.options.receiveTimeout = Duration(seconds: 3);
    dio.options.followRedirects = false;
    dio.options.headers = {
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36 Edg/91.0.864.64',
      'Accept': 'application/json, text/javascript, */*; q=0.01',
      'Accept-Encoding': 'gzip, deflate, br',
      'Cookie':
          "userToken=${token}; Domain=v8mobile.hut.edu.cn; Path=/; JSESSIONID=${JSESSIONID}",
    };
  }

  Future<Response> postDio(String path, Map postData) async {
    Response response;
    response = await dio.post(path, data: postData);
    //print(response.data);
    return response;
  }

  Future<int> getUserInfo() async {
    final userDio = Dio();
    userDio.options.baseUrl = 'https://authx-service.hut.edu.cn';
    userDio.options.connectTimeout = Duration(seconds: 5);
    userDio.options.receiveTimeout = Duration(seconds: 3);
    userDio.options.followRedirects = false;
    userDio.options.headers = {
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36 Edg/91.0.864.64',
      'Accept': 'application/json, text/javascript, */*; q=0.01',
      'Accept-Encoding': 'gzip, deflate, br',
      'X-Id-Token': token,
    };
    Response response;
    response = await userDio.get('/personal/api/v1/personal/me/user');
    Map data = response.data;
    Map user = data['data'];
    username = user['username'];
    print(username);
    return 1;
  }

  //获取历史记录
  Future<Map> getHistory() async {
    Response response;
    response = await postDio(
      '/myaccount/querywechatUserLastInfo?openid=${openid}',
      {"idserial": username, "openid": openid},
    );
    Map data = response.data;
    Map history = data['resultData'];
    String elelastBindStr = history['elelastbind'];
    Map elelastbind = jsonDecode(elelastBindStr);
    factorycode = elelastbind['factorycode'];
    areaid = elelastbind['areaid'];
    roomid = elelastbind['roomid'];
    buildingid = elelastbind['buildingid'];
    return {
      "factorycode": factorycode,
      "areaid": areaid,
      "roomid": roomid,
      "buildingid": buildingid,
    };
  }

  //获取当个房间信息
  Future<Map> getSingleRoomInfo(String troomid) async {
    print("GETING");
    Response response;
    response = await postDio('/channel/queryRoomDetail?openid=${openid}', {
      "areaid": areaid,
      "buildingid": buildingid,
      "factorycode": factorycode,
      "roomid": troomid,
    });
    Map data = response.data;
    Map roomInfo = data['resultData'];
    String eleTail = roomInfo['eledetail'];
    String roomName = roomInfo['accname'];
    print(roomInfo);
    return {"roomName": roomName, "eleTail": eleTail};
  }

  //获取所有房间列表
  Future<List> getRoomList() async {
    Response response;
    response = await postDio('/channel/getAllAccountInfo?openid=${openid}', {
      "areaid": areaid,
      "buildingid": buildingid,
      "factorycode": factorycode,
    });
    Map data = response.data;
    Map roomListA = data['resultData'];
    List roomList = roomListA['jsonArr'];
    print(roomList.length);
    return roomList;
  }

  //充值前检测
  Future<bool> checkBeforeRecharge(String payRoomId) async {
    Response response;
    response = await postDio('/myaccount/userlastbind?openid=${openid}', {
      "payinfo": {"elepayWay": "6"},
      "eleinfo": {
        "buildingid": buildingid,
        "areaid": areaid,
        "roomid": payRoomId,
        "factorycode": factorycode,
      },
      "idserial": username,
    });
    Map data = response.data;
    if (data['success'] == true) {
      return true;
    } else {
      return false;
    }
  }

  //创建订单
  Future<Map> createOrder(
    String payRoomId,
    String count,
    String payRoomName,
  ) async {
    Response response;
    response = await postDio('/elepay/createPreThirdTrade?openid=${openid}', {
      "payamt": count,
      "openid": openid,
      "idserial": username,
      "factorycode": factorycode,
      "buildingid": buildingid,
      "areaid": areaid,
      "roomid": payRoomId,
      "roomvalue": payRoomName,
      "paytype": "6",
    });
    Map data = response.data;
    Map resultData = data['resultData'];
    String partnerjourno = resultData['partnerjourno'];
    String payorderno = resultData['payorderno'];
    String txdate = resultData['txdate'];
    return {
      "partnerjourno": partnerjourno,
      "payorderno": payorderno,
      "txdate": txdate,
    };
  }

  //完成充值
  finishRecharge(String payorderno, String count, String payRoomName) async {
    Response response;
    response = await postDio('/elepay/consumeFromYktToEle?openid=${openid}', {
      "paytxamt": count,
      "payWay": "6",
      "openid": openid,
      "idserial": username,
      "payorderno": payorderno,
      "factorycode": factorycode,
      "roomname": payRoomName,
    });
    Map data = response.data;
    String message = data['message'];
    print(message);
  }
}
