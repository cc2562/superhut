Page({
  data: {
    services: [
      {
        title: '成绩',
        initial: '成',
        description: '按学期查看课程成绩、学分与绩点',
        route: '/pages/scores/index',
        tone: 'green',
      },
      {
        title: '考试',
        initial: '考',
        description: '查看考试科目、时间与地点',
        route: '/pages/exams/index',
        tone: 'blue',
      },
      {
        title: '空教室',
        initial: '室',
        description: '按日期、教学楼和节次查询',
        route: '/pages/rooms/index',
        tone: 'purple',
      },
      {
        title: '评教',
        initial: '评',
        description: '查看待评课程，支持手动或一键评教',
        route: '/pages/evaluation/batches/index',
        tone: 'orange',
      },
    ],
  },
  open(event: WechatMiniprogram.BaseEvent) {
    void wx.navigateTo({ url: event.currentTarget.dataset.route as string });
  },
});
