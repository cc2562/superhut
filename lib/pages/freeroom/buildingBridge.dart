import '../../command/roomapi.dart';
bool isGet=false,isRoomGet=false;
List<Building> buildingList = [];
List<Room> roomList = [];
Future<List<Building>> GetBuilding() async {
  if(isGet){
    return buildingList;
  }
  var api = FreeBuildingApi();
  await api.initData();
  await api.getCurrentTerm();
  buildingList =await api.getBuildingList();
  isGet=true;
  return buildingList;
}

Future<List<Room>> getRoom(String date, String nodeId, String buildingId,bool reFlash) async {

  var api = FreeRoomApi();
  await api.initData();
  roomList = await api.getFreeRoomList(date, nodeId, buildingId);
  return roomList;
}