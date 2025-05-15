import 'package:superhut/utils/withhttp.dart';
import 'package:dio/dio.dart';
import '../../utils/token.dart';

Future<List> getSchedule() async {
  late String token;
  token = await getToken();
  configureDio(token);
  Response response;
  response = await postDio('/njwhd/student/examinationArrangement', {});
  Map data = response.data;
  List schedules = data['data'];
  return schedules;
}