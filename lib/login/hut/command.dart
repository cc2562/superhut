import 'dart:math';
import 'dart:typed_data';

import 'package:superhut/pages/drink/api/drink_api.dart';
import 'package:flutter/material.dart';

import '../../utils/hut_user_api.dart';


var api = HutUserApi();
String doubleRandom ="0";
String timestamp = DateTime.timestamp().millisecondsSinceEpoch.toString();
bool first =true;





void loginToHuT(String username,String password,context){
  api.userLogin(username: username, password: password).then((value) {
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