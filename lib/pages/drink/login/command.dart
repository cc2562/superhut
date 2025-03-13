import 'dart:math';
import 'dart:typed_data';
import 'package:superhut/pages/drink/api/drink_api.dart';
import 'package:flutter/material.dart';
import 'loginpart2.dart';

var api = DrinkApi();
String doubleRandom ="0";
String timestamp = DateTime.timestamp().millisecondsSinceEpoch.toString();
bool first =true;
Future<Uint8List> GetImageCaptcha() async {
  if(first) {
    doubleRandom = Random().nextDouble().toString();
    print(doubleRandom);
    Uint8List data = await api.userCaptcha(
        doubleRandom: doubleRandom, timestamp: timestamp);
    first =false;
    return data;
  }
  return Uint8List(0);
}

void to2Login(context,String phoneNumber,String imageCode){
  Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => DrinkLoginPage2(phoneNumber: phoneNumber, doubleRandom: doubleRandom, timestamp: timestamp, imageCode: imageCode,)),
  );
}

void SendMessageCode(context,String phoneNumber,String imageCode){
  print(doubleRandom);
  print(imageCode);
  api.userMessageCode(doubleRandom: doubleRandom, photoCode: imageCode, phone: phoneNumber).then((value) {
    if(value){
      to2Login(context,phoneNumber,imageCode);
    }else{
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('验证码错误')),
      );
    }
  });
}

void Login(String phoneNumber,String code,context){
  api.userLogin(phone: phoneNumber,messageCode: code).then((value) {
    if(value){
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('成功')),
      );
      Navigator.pop(context);
    }else{
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('登录失败')),
      );
    }
  });
}