const logUrl = 'https://errlog.umeng.com/apm_logs';

enum ACTIONS {
  SET_SESSION_ID,
  SET_DART_VERSION,
  SET_PV_ID,
  SET_PAGE_NAME,
  PROCESSOR_EXCEPTION_EVENT,
  SEND_EXCEPTION_LOG,
  SEND_PV_LOG,
  SEND_PAGE_PERF_LOG,
  SEND_PAGE_FPS_LOG,
  SEND_API_LOG,
  START_TIMER_POLL,
  SET_DEVICE_MAX_FPS
}

enum ReportLogType { exception, pv, api, page_perf, page_fps, perf }

enum ReportQueueType { send, pre }

const KEY_FLUTTER = 'flutter';
const KEY_APP_STATUS = 'appStatus';
const KEY_TYPE = 'type';
const KEY_MAX_FPS = 'maxFps';
const KEY_LOG = 'log';
const KEY_COMMON = 'common';
const KEY_FLUTTER_PERF = 'flutterperf';
const KEY_FLUTTER_ERROR = 'fluttererror';
const KEY_DSN = 'dsn';
const KEY_APPID = 'appid';
const KEY_UMID_HEADER = 'um_umid_header';
const KEY_UMID = 'um_umid';
const KEY_SDK_VERSION = 'sdkVersion';
const KEY_CODE = 'code';
const KEY_ERRORFILTER = 'errorFilter';
const KEY_MODE = 'mode';
const KEY_RULES = 'rules';
const KEY_MSG = 'msg';
const KEY_NAME = 'name';
const KEY_VALUE = 'value';
const KEY_PVID = 'pvId';
const KEY_MD5 = 'md5';
const KEY_DATA = 'data';
const KEY_BASEINFO = 'baseInfo';
const KEY_HANDLER = 'handler';
const KEY_USE_BOOST_PLUGIN = 'useBoostPlugin';
const KEY_PV_MAX_COUNT = 'flutter_pv_max_count';
const KEY_PV_CURRENT_COUNT = 'flutter_pv_current_count';
const KEY_DART_EXCEPTION_MAX_COUNT = 'flutter_dart_exception_max_count';
const KEY_DART_EXCEPTION_CURRENT_COUNT = 'flutter_dart_exception_current_count';
const KEY_LAST_LOG_REPORT_TIME = 'last_log_report_time';
const KEY_PV_SAMPLING_HIT = 'flutter_pv_sampling_hit';
const KEY_DART_EXCEPTION_STATE = 'flutter_dart_exception_state';
const KEY_PV_DETAIL_SAMPLING_HIT = 'flutter_pv_detail_sampling_hit';
const KEY_API_SAMPLING_HIT = 'flutter_http_sampling_hit';
