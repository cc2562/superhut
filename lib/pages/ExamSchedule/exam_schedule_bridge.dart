import 'package:dio/dio.dart';
import 'package:superhut/utils/withhttp.dart';

Future<List> getSchedule() async {
  await configureDioFromStorage();
  Response response;
  response = await postDioWithCookie(
    '/njwhd/student/examinationArrangement',
    {},
  );
  Map data = response.data;
  List schedules = data['data'];
  return schedules;
}
