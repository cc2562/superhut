
import 'package:dio/dio.dart';
import 'package:superhut/utils/token.dart';
import 'package:superhut/utils/withhttp.dart';


late String currentTerm;
class Building{
  final String name;
  final String count;
  final String buildingId;
  final String free;

  Building({
    required this.name,
    required this.count,
    required this.buildingId,
    required this.free,
  });
}
class Room{
  final String name;
  final String seatNumber;
  final List<String> free;

  Room({
    required this.name,
    required this.seatNumber,
    required this.free,
  });
}
class FreeBuildingApi {
  late String token;

  List<Building> buildingList = [];

  Future<void> initData() async {
    token = await getToken();
    configureDio(token);
  }

  Future<String> getCurrentTerm() async {
    Response response;
    response = await postDio('/njwhd/currentTerm', {});
    Map data = response.data;
    Map termData = data['data'][0];
    currentTerm = termData['semesterId'];
    return currentTerm;
  }

  Future<List<Building>> getBuildingList() async {
    Response response;
    response = await postDio(
      '/njwhd/student/getIdleClassroom?campusId=&jiaoxueloumc=&zhouci=40&xnxq=$currentTerm&searchType=lylv',
      {},
    );
    Map data = response.data;
    //List buildingList = data['data'];
    List<Map<String, dynamic>> buildingListData = List<Map<String, dynamic>>.from(data['data']);
    print(buildingListData.length);
    for (int i=0;i<buildingListData.length;i++) {
      var tbuilding = buildingListData[i];

      buildingList.add(Building(
        name: tbuilding['teachingBuildingName'],
        count: tbuilding['count'],
        buildingId: tbuilding['buildingId'], free: tbuilding['kxs'],
      ));
    }
    return buildingList;
  }
}

class FreeRoomApi{
  late String token;
  List<Room> roomList = [];

  Future<void> initData() async {
    token = await getToken();
    configureDio(token);
  }
  String processString(String input) {
    if (input.length <= 2) {
      // 如果字符串长度小于等于2，直接返回空字符串或其他适当的值
      return '';
    }
    // 去除第一个字符，并返回最后两个字符
    return input.substring(1, input.length);
  }
  List<String> stringToList(String input) {
    List<String> tempList = input.split(',');
    List<String> result = [];
    for(var i = 0; i < tempList.length; i++){
      result.add(processString(tempList[i]));
    }
    print(result);
    return result;
  }



  Future<List<Room>> getFreeRoomList(String date,String nodeId,String buildingId) async {
    Response response;
    response = await postDio(
      '/njwhd/student/getIdleClassroom?date=$date&nodeId=$nodeId&buildingId=$buildingId&campusId=&jsmc=&xnxq=$currentTerm&jiaoxueloumc=',
      {},
    );
     Map data = response.data;
    // print(data);
     List roomListData = data['data'];
     for (var room in roomListData) {
       List<String> freeList =[];
       if(room['zyjc'] == ""){
         print("YES");
         freeList = ['00'];
       }else{
         freeList = stringToList(room['zyjc']);
       }

       roomList.add(Room(
         name: room['classroomname'],
         seatNumber: room['seatnumber'],
         free: freeList,
       ));
     }
     print(roomList[0].name);
     return roomList;
  }
}
