import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tencent_im_sdk_plugin/models/v2_tim_message.dart';
import 'package:tim_ui_kit/business_logic/view_models/tui_theme_view_model.dart';
import 'package:tim_ui_kit/i18n/i18n_utils.dart';
import 'package:tim_ui_kit/ui/views/TIMUIKitSearch/pureUI/tim_uikit_search_input.dart';
import 'package:tim_ui_kit/ui/views/TIMUIKitSearch/pureUI/tim_uikit_search_item.dart';
import 'package:tim_ui_kit/business_logic/view_models/tui_search_view_model.dart';
import 'package:tim_ui_kit/data_services/services_locatar.dart';
import 'package:tim_ui_kit/ui/views/TIMUIKitSearch/pureUI/tim_uikit_search_showAll.dart';
import '../../../tim_ui_kit.dart';

class TIMUIKitSearchMsgDetail extends StatefulWidget {
  final V2TimConversation currentConversation;
  final String keyword;
  final Function(V2TimConversation, int?) onTapConversation;

  const TIMUIKitSearchMsgDetail(
      {Key? key,
      required this.currentConversation,
      required this.keyword,
      required this.onTapConversation})
      : super(key: key);

  @override
  State<StatefulWidget> createState() => TIMUIKitSearchMsgDetailState();
}

class TIMUIKitSearchMsgDetailState extends State<TIMUIKitSearchMsgDetail>{
  final model = serviceLocator<TUISearchViewModel>();
  String keywordState = "";
  int currentPage = 0;

  @override
  void initState() {
    super.initState();
    keywordState = widget.keyword;
    updateMsgResult(widget.keyword, true);
  }

  String _getMsgElem(V2TimMessage message, BuildContext context) {
    final I18nUtils ttBuild = I18nUtils(context);
    final msgType = message.elemType;
    final isRevokedMessage = message.status == 6;
    if (isRevokedMessage) {
      final isSelf = message.isSelf ?? false;
      final displayName =
      isSelf ? ttBuild.imt("您") : message.nickName ?? message.sender;
      return ttBuild.imt_para(
          "{{displayName}}撤回了一条消息", "$displayName撤回了一条消息")(
          displayName: displayName);
    }
    switch (msgType) {
      case MessageElemType.V2TIM_ELEM_TYPE_CUSTOM:
        return ttBuild.imt("[自定义]");
      case MessageElemType.V2TIM_ELEM_TYPE_SOUND:
        return ttBuild.imt("[语音]");
      case MessageElemType.V2TIM_ELEM_TYPE_TEXT:
        return message.textElem!.text as String;
      case MessageElemType.V2TIM_ELEM_TYPE_FACE:
        return ttBuild.imt("[表情]");
      case MessageElemType.V2TIM_ELEM_TYPE_FILE:
        final fileName = message.fileElem!.fileName;
        return ttBuild.imt_para("[文件] {{fileName}}", "[文件] $fileName")(
            fileName: fileName);
      case MessageElemType.V2TIM_ELEM_TYPE_IMAGE:
        return ttBuild.imt("[图片]");
      case MessageElemType.V2TIM_ELEM_TYPE_VIDEO:
        return ttBuild.imt("[视频]");
      case MessageElemType.V2TIM_ELEM_TYPE_LOCATION:
        return ttBuild.imt("[位置]");
      case MessageElemType.V2TIM_ELEM_TYPE_MERGER:
        return ttBuild.imt("[聊天记录]");
      default:
        return ttBuild.imt("未知消息");
    }
  }

  List<Widget> _renderListMessage(
      List<V2TimMessage> msgList, BuildContext context) {
    List<Widget> listWidget = [];

    listWidget = msgList.map((message) {
      return Container(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
        decoration: const BoxDecoration(
          color: Colors.white,
        ),
        child: TIMUIKitSearchItem(
          faceUrl: message.faceUrl ?? "",
          showName: message.nickName ?? message.userID ?? "",
          lineOne: message.nickName ?? message.userID ?? "",
          lineTwo: _getMsgElem(message, context),
          onClick: () {
            widget.onTapConversation(widget.currentConversation, message.timestamp);
          },
        ),
      );
    }).toList();
    return listWidget;
  }

  updateMsgResult(String? keyword, bool isNewSearch){
    if(isNewSearch){
      setState(() {
        currentPage = 0;
        keywordState = keyword!;
      });
    }
    model.getMsgForConversation(
        keyword ?? keywordState, widget.currentConversation.conversationID, currentPage);
    setState(() {
      currentPage = currentPage + 1;
    });
  }

  Widget _renderShowALl(bool isShowMore, I18nUtils ttBuild){
    return (isShowMore == true) ? Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      decoration: const BoxDecoration(
      color: Colors.white,
    ),
      child: TIMUIKitSearchShowALl(
        textShow: ttBuild.imt("更多聊天记录"),
        onClick: () => {
          updateMsgResult(null, false)
        },
      ),
    ) : Container();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(
            value: serviceLocator<TUIThemeViewModel>()),
        ChangeNotifierProvider.value(
            value: serviceLocator<TUISearchViewModel>())
      ],
      builder: (context, w) {
        final I18nUtils ttBuild = I18nUtils(context);
        final theme = Provider.of<TUIThemeViewModel>(context).theme;
        final List<V2TimMessage> currentMsgListForConversation =
            Provider.of<TUISearchViewModel>(context)
                .currentMsgListForConversation;
        final int totalMsgInConversationCount =
            Provider.of<TUISearchViewModel>(context).totalMsgInConversationCount;
        return GestureDetector(
          onTap: (){
            FocusScopeNode currentFocus = FocusScope.of(context);
            if (!currentFocus.hasPrimaryFocus) {
              currentFocus.unfocus();
            }
          },
          child: Scaffold(
              appBar: AppBar(
                  elevation: 0,
                  backgroundColor: theme.primaryColor,
                  iconTheme: const IconThemeData(
                      color: Colors.white,
                  ),
                  title: Text(
                    widget.currentConversation.showName ?? ttBuild.imt("相关聊天记录"),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                    ),
                  )),
              body: Column(
                children: [
                  TIMUIKitSearchInput(
                    onChange: (String value) {
                      updateMsgResult(value, true);
                    },
                    initValue: widget.keyword,
                    prefixText: Text(widget.currentConversation.showName ??
                        widget.currentConversation.userID ??
                        ""),
                  ),
                  Expanded(
                      child: ListView(
                        children: [..._renderListMessage(
                            currentMsgListForConversation, context),
                          _renderShowALl(keywordState.isNotEmpty &&
                              totalMsgInConversationCount > currentMsgListForConversation.length, ttBuild)],
                      )),
                ],
              )),
        );
      },
    );
  }

}