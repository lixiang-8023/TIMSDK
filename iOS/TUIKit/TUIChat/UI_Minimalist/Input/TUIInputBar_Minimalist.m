//
//  TUIInputBar_Minimalist.m
//  UIKit
//
//  Created by kennethmiao on 2018/9/18.
//  Copyright © 2018年 Tencent. All rights reserved.
//

#import "TUIInputBar_Minimalist.h"
#import "TUIDefine.h"
#import "TUITool.h"
#import "TUIDefine.h"
#import "ReactiveObjC/ReactiveObjC.h"
#import "UIView+TUILayout.h"
#import "TUIDarkModel.h"
#import "TUIGlobalization.h"
#import "NSTimer+TUISafe.h"
#import "NSString+TUIEmoji.h"
#import "TUICore.h"
#import "TUIAudioRecorder.h"

@interface TUIInputBar_Minimalist() <UITextViewDelegate, TUIAudioRecorderDelegate>

@property (nonatomic, strong) NSDate *recordStartTime;
@property (nonatomic, strong) TUIAudioRecorder *recorder;
@property (nonatomic, strong) NSTimer *recordTimer;

@property (nonatomic, assign) BOOL isFocusOn;
@property (nonatomic, strong) NSTimer *sendTypingStatusTimer;
@property (nonatomic, assign) BOOL allowSendTypingStatusByChangeWord;
@end

@implementation TUIInputBar_Minimalist

- (void)dealloc {
    if(_sendTypingStatusTimer){
        [_sendTypingStatusTimer invalidate];
        _sendTypingStatusTimer = nil;
    }
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if(self){
        [self setupViews];
        [self defaultLayout];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onThemeChanged) name:TUIDidApplyingThemeChangedNotfication object:nil];
    }
    return self;
}

- (void)setupViews
{
    self.backgroundColor = RGBA(255, 255, 255, 1);

    _lineView = [[UIView alloc] init];
    _lineView.backgroundColor = TUICoreDynamicColor(@"separator_color", @"#FFFFFF");

    _moreButton = [[UIButton alloc] init];
    [_moreButton addTarget:self action:@selector(clickMoreBtn:) forControlEvents:UIControlEventTouchUpInside];
    [_moreButton setImage:[[TUIImageCache sharedInstance] getResourceFromCache:TUIChatImagePath_Minimalist(@"TypeSelectorBtnHL_Black")]         forState:UIControlStateNormal];
    [_moreButton setImage:[[TUIImageCache sharedInstance] getResourceFromCache:TUIChatImagePath_Minimalist(@"TypeSelectorBtnHL_Black")]
                 forState:UIControlStateHighlighted];
    [self addSubview:_moreButton];

    _inputTextView = [[TUIResponderTextView_Minimalist alloc] init];
    _inputTextView.delegate = self;
    [_inputTextView setFont:kTUIInputNoramlFont];
    _inputTextView.backgroundColor = TUIChatDynamicColor(@"chat_input_bg_color", @"#FFFFFF");
    _inputTextView.textColor = TUIChatDynamicColor(@"chat_input_text_color", @"#000000");
    _inputTextView.textContainerInset = UIEdgeInsetsMake(kScale390(9), kScale390(16), kScale390(9), kScale390(30));
    [_inputTextView setReturnKeyType:UIReturnKeySend];
    [self addSubview:_inputTextView];
    
    _keyboardButton = [[UIButton alloc] init];
    [_keyboardButton addTarget:self action:@selector(clickKeyboardBtn:) forControlEvents:UIControlEventTouchUpInside];
    [_keyboardButton setImage:TUIChatBundleThemeImage(@"chat_ToolViewKeyboard_img", @"ToolViewKeyboard") forState:UIControlStateNormal];
    [_keyboardButton setImage:TUIChatBundleThemeImage(@"chat_ToolViewKeyboardHL_img", @"ToolViewKeyboardHL")
                     forState:UIControlStateHighlighted];
    _keyboardButton.hidden = YES;
    [self addSubview:_keyboardButton];
    
    _faceButton = [[UIButton alloc] init];
    [_faceButton addTarget:self action:@selector(clickFaceBtn:) forControlEvents:UIControlEventTouchUpInside];
    [_faceButton setImage: [[TUIImageCache sharedInstance] getResourceFromCache:TUIChatImagePath_Minimalist(@"ToolViewEmotion")]
                 forState:UIControlStateNormal];
    [_faceButton setImage: [[TUIImageCache sharedInstance] getResourceFromCache:TUIChatImagePath_Minimalist(@"ToolViewEmotion")]
                 forState:UIControlStateHighlighted];
    [self addSubview:_faceButton];
    
    _micButton = [[UIButton alloc] init];
    [_micButton addTarget:self action:@selector(recordBtnDown:) forControlEvents:UIControlEventTouchDown];
    [_micButton addTarget:self action:@selector(recordBtnUp:) forControlEvents:UIControlEventTouchUpInside];
    [_micButton addTarget:self action:@selector(recordBtnCancel:) forControlEvents:UIControlEventTouchUpOutside | UIControlEventTouchCancel];
    [_micButton addTarget:self action:@selector(recordBtnDragExit:) forControlEvents:UIControlEventTouchDragExit];
    [_micButton addTarget:self action:@selector(recordBtnDragEnter:) forControlEvents:UIControlEventTouchDragEnter];
    [_micButton setImage:[[TUIImageCache sharedInstance] getResourceFromCache:TUIChatImagePath_Minimalist(@"ToolViewInputVoice")]   forState:UIControlStateNormal];
    [self addSubview:_micButton];
    
    _cameraButton = [[UIButton alloc] init];
    [_cameraButton addTarget:self action:@selector(clickCameraBtn:) forControlEvents:UIControlEventTouchUpInside];
    [_cameraButton setImage:[[TUIImageCache sharedInstance] getResourceFromCache:TUIChatImagePath_Minimalist(@"ToolViewInputCamera")]          forState:UIControlStateNormal];
    [_cameraButton setImage: [[TUIImageCache sharedInstance] getResourceFromCache:TUIChatImagePath_Minimalist(@"ToolViewInputCamera")]
                forState:UIControlStateHighlighted];
    [self addSubview:_cameraButton];
    
    [self initRecordView];
}

- (void)initRecordView {
    _recordView = [[UIView alloc] init];
    _recordView.backgroundColor = RGBA(255, 255, 255, 1);
    _recordView.hidden = YES;
    [self addSubview:_recordView];
    
    _recordDeleteView = [[UIImageView alloc] init];
    [_recordView addSubview:_recordDeleteView];
    
    _recordBackgroudView = [[UIView alloc] init];
    [_recordView addSubview:_recordBackgroudView];
    
    _recordTimeLabel = [[UILabel alloc] init];
    _recordTimeLabel.textColor = [UIColor whiteColor];
    _recordTimeLabel.font = [UIFont systemFontOfSize:14];
    [_recordView addSubview:_recordTimeLabel];
    
    _recordAnimateViews = [NSMutableArray array];
    for (int i = 0 ; i < 6; i ++) {
        UIImageView *recordAnimateView = [[UIImageView alloc] init];
        [recordAnimateView setImage:[[TUIImageCache sharedInstance] getResourceFromCache:TUIChatImagePath_Minimalist(@"voice_record_animation")]];
        [_recordView addSubview:recordAnimateView];
        [_recordAnimateViews addObject:recordAnimateView];
    }
    
    _recordAnimateCoverView = [[UIImageView alloc] init];
    [_recordView addSubview:_recordAnimateCoverView];
    
    _recordTipsView = [[UIView alloc] init];
    _recordTipsView.backgroundColor = [UIColor whiteColor];
    _recordTipsView.frame = CGRectMake(0, -56, Screen_Width, 56);
    [_recordView addSubview:_recordTipsView];
    
    _recordTipsLabel = [[UILabel alloc] init];
    _recordTipsLabel.textColor = RGBA(102, 102, 102, 1);
    _recordTipsLabel.textColor = [UIColor blackColor];
    _recordTipsLabel.text = TUIKitLocalizableString(TUIKitInputRecordTipsTitle);
    _recordTipsLabel.textAlignment = NSTextAlignmentCenter;
    _recordTipsLabel.font = [UIFont systemFontOfSize:14];
    _recordTipsLabel.frame = CGRectMake(0, 10, Screen_Width, 22);
    [_recordTipsView addSubview:_recordTipsLabel];
    
    [self setRecordStatus:TUIRecordStatus_Init];
}

- (void)setRecordStatus:(TUIRecordStatus)status {
    switch (status) {
        case TUIRecordStatus_Init:
        case TUIRecordStatus_Record:
        case TUIRecordStatus_Cancel:
            {
                _recordDeleteView.frame = CGRectMake(kScale390(16), _recordDeleteView.mm_y, 24, 24);
                _recordDeleteView.image = [[TUIImageCache sharedInstance] getResourceFromCache:TUIChatImagePath_Minimalist(@"voice_record_delete")];
                _recordBackgroudView.backgroundColor = RGBA(20, 122, 255, 1);
                _recordAnimateCoverView.backgroundColor = _recordBackgroudView.backgroundColor;
                _recordAnimateCoverView.frame = self.recordAnimateCoverViewFrame;
                _recordTimeLabel.text = @"0:00";
                _recordTipsLabel.text = TUIKitLocalizableString(TUIKitInputRecordTipsTitle);
                
                if (TUIRecordStatus_Record == status) {
                    _recordView.hidden = NO;
                } else {
                    _recordView.hidden = YES;
                }
            }
            break;
        case TUIRecordStatus_Delete:
            {
                _recordDeleteView.frame = CGRectMake(0, _recordDeleteView.mm_y, 20, 24);
                _recordDeleteView.image = [[TUIImageCache sharedInstance] getResourceFromCache:TUIChatImagePath_Minimalist(@"voice_record_delete_ready")];
                _recordBackgroudView.backgroundColor = RGBA(255, 88, 76, 1);
                _recordAnimateCoverView.backgroundColor = _recordBackgroudView.backgroundColor;
                _recordTipsLabel.text = TUIKitLocalizableString(TUIKitInputRecordCancelTipsTitle);
                
                _recordView.hidden = NO;
            }
            break;
        default:
            break;
    }
}

- (void)applyBorderTheme {
    if (_recordBackgroudView) {
        [_recordBackgroudView.layer setMasksToBounds:YES];
        [_recordBackgroudView.layer setCornerRadius:_recordBackgroudView.mm_h / 2.0];
    }
    
    if (_inputTextView) {
        [_inputTextView.layer setMasksToBounds:YES];
        [_inputTextView.layer setCornerRadius:_inputTextView.mm_h / 2.0];
        [_inputTextView.layer setBorderWidth:0.5f];
        [_inputTextView.layer setBorderColor:RGBA(221, 221, 221, 1).CGColor];
    }
    
}
- (void)defaultLayout
{
    _lineView.frame = CGRectMake(0, 0, Screen_Width, TLine_Heigh);
    
    CGFloat iconSize = 24;
    _moreButton.frame = CGRectMake(kScale390(16), kScale390(13), iconSize, iconSize);
    _cameraButton.frame = CGRectMake(Screen_Width - kScale390(16) - iconSize, 13, iconSize, iconSize);
    _micButton.frame = CGRectMake(Screen_Width - kScale390(56) - iconSize, 13, iconSize, iconSize);
    
    CGFloat faceSize = 19;
    _faceButton.frame = CGRectMake(_micButton.mm_x - kScale390(50), 15, faceSize, faceSize);
    _keyboardButton.frame = _faceButton.frame;
    _inputTextView.frame = CGRectMake(kScale390(56), 7, Screen_Width - kScale390(152), 36);
    
    _recordView.frame = CGRectMake(0, _inputTextView.mm_y, self.mm_w, _inputTextView.mm_h);
    _recordDeleteView.frame = CGRectMake(kScale390(16), 4, iconSize, iconSize);
    _recordBackgroudView.frame = CGRectMake(kScale390(54), 0, self.mm_w - kScale390(70), _recordView.mm_h);
    _recordTimeLabel.frame = CGRectMake(kScale390(70), kScale390(7), 32, 22);
    
    CGFloat animationStartX = kScale390(112);
    CGFloat animationY = 8;
    CGFloat animationSize = 20;
    CGFloat animationSpace = kScale390(8);
    CGFloat animationCoverWidth = 0;
    for (int i = 0; i < self.recordAnimateViews.count; ++i) {
        UIView *animationView = self.recordAnimateViews[i];
        animationView.frame = CGRectMake(animationStartX + (animationSize + animationSpace) * i, animationY, animationSize, animationSize);
        animationCoverWidth = (animationSize + animationSpace) * (i + 1);
    }
    _recordAnimateCoverViewFrame = CGRectMake(animationStartX, animationY, animationCoverWidth, animationSize);
    _recordAnimateCoverView.frame = self.recordAnimateCoverViewFrame;
    [self applyBorderTheme];
}

- (void)layoutButton:(CGFloat)height
{
    CGRect frame = self.frame;
    CGFloat offset = height - frame.size.height;
    frame.size.height = height;
    self.frame = frame;

    if(_delegate && [_delegate respondsToSelector:@selector(inputBar:didChangeInputHeight:)]){
        [_delegate inputBar:self didChangeInputHeight:offset];
    }
}

- (void)clickCameraBtn:(UIButton *)sender
{
    _micButton.hidden = NO;
    _keyboardButton.hidden = YES;
    _inputTextView.hidden = NO;
    _faceButton.hidden = NO;
    [self setRecordStatus:TUIRecordStatus_Cancel];
    if(_delegate && [_delegate respondsToSelector:@selector(inputBarDidTouchCamera:)]){
        [_delegate inputBarDidTouchCamera:self];
    }
}

- (void)clickKeyboardBtn:(UIButton *)sender
{
    _micButton.hidden = NO;
    _keyboardButton.hidden = YES;
    _inputTextView.hidden = NO;
    _faceButton.hidden = NO;
    [self setRecordStatus:TUIRecordStatus_Cancel];
    [self layoutButton:_inputTextView.frame.size.height + 2 * TTextView_Margin];
    if(_delegate && [_delegate respondsToSelector:@selector(inputBarDidTouchKeyboard:)]){
        [_delegate inputBarDidTouchKeyboard:self];
    }
}

- (void)clickFaceBtn:(UIButton *)sender
{
    _micButton.hidden = NO;
    _faceButton.hidden = YES;
    _keyboardButton.hidden = NO;
    _inputTextView.hidden = NO;
    [self setRecordStatus:TUIRecordStatus_Cancel];
    if(_delegate && [_delegate respondsToSelector:@selector(inputBarDidTouchFace:)]){
        [_delegate inputBarDidTouchFace:self];
    }
    _keyboardButton.frame = _faceButton.frame;
}

- (void)clickMoreBtn:(UIButton *)sender
{
    if(_delegate && [_delegate respondsToSelector:@selector(inputBarDidTouchMore:)]){
        [_delegate inputBarDidTouchMore:self];
    }
}

- (void)recordBtnDown:(UIButton *)sender
{
    [self.recorder record];
}

- (void)recordBtnUp:(UIButton *)sender
{
    NSTimeInterval interval = [[NSDate date] timeIntervalSinceDate:_recordStartTime];
    if (interval < 1) {
        [self.recorder cancel];
    } else if (interval > 60) {
        [self.recorder cancel];
    } else {
        [self.recorder stop];
        NSString *path = self.recorder.recordedFilePath;
        if (path) {
            if(_delegate && [_delegate respondsToSelector:@selector(inputBar:didSendVoice:)]){
                [_delegate inputBar:self didSendVoice:path];
            }
        }
    }
    [self setRecordStatus:TUIRecordStatus_Cancel];
}

- (void)recordBtnCancel:(UIGestureRecognizer *)gesture
{
    [self setRecordStatus:TUIRecordStatus_Cancel];
    [self.recorder cancel];
}

- (void)recordBtnDragExit:(UIButton *)sender
{
    [self setRecordStatus:TUIRecordStatus_Delete];
}

- (void)recordBtnDragEnter:(UIButton *)sender
{
    [self setRecordStatus:TUIRecordStatus_Record];
}

- (void)showHapticFeedback{
    if (@available(iOS 10.0, *)) {
        dispatch_async(dispatch_get_main_queue(), ^{
            UIImpactFeedbackGenerator *generator = [[UIImpactFeedbackGenerator alloc] initWithStyle: UIImpactFeedbackStyleMedium];
            [generator prepare];
            [generator impactOccurred];
        });
        
    } else {
        // Fallback on earlier versions
    }
}
#pragma mark - talk

- (void)textViewDidBeginEditing:(UITextView *)textView
{
    self.keyboardButton.hidden = YES;
    self.micButton.hidden = NO;
    self.faceButton.hidden = NO;
    
    self.isFocusOn = YES;
    self.allowSendTypingStatusByChangeWord  = YES;

    
    __weak typeof(self) weakSelf = self;
    self.sendTypingStatusTimer = [NSTimer tui_scheduledTimerWithTimeInterval:4 repeats:YES block:^(NSTimer * _Nonnull timer) {
        __strong typeof(weakSelf)strongSelf = weakSelf;
        strongSelf.allowSendTypingStatusByChangeWord = YES;
    }];
    
    if (self.isFocusOn &&[textView.textStorage getPlainString].length > 0) {
        if (_delegate && [_delegate respondsToSelector:@selector(inputTextViewShouldBeginTyping:)]) {
            [_delegate inputTextViewShouldBeginTyping:textView];
        }
    }
}

- (void)textViewDidEndEditing:(UITextView *)textView {
    
    self.isFocusOn = NO;
    if (_delegate && [_delegate respondsToSelector:@selector(inputTextViewShouldEndTyping:)]) {
        [_delegate inputTextViewShouldEndTyping:textView];
    }
}

- (void)textViewDidChange:(UITextView *)textView
{
    if (self.allowSendTypingStatusByChangeWord && self.isFocusOn &&[textView.textStorage getPlainString].length > 0) {
        if (_delegate && [_delegate respondsToSelector:@selector(inputTextViewShouldBeginTyping:)]) {
            self.allowSendTypingStatusByChangeWord = NO;
            [_delegate inputTextViewShouldBeginTyping:textView];
        }
    }
    
    if (self.isFocusOn && [textView.textStorage getPlainString].length == 0) {
        if (_delegate && [_delegate respondsToSelector:@selector(inputTextViewShouldEndTyping:)]) {
            [_delegate inputTextViewShouldEndTyping:textView];
        }
    }
    CGSize size = [_inputTextView sizeThatFits:CGSizeMake(_inputTextView.frame.size.width, TTextView_TextView_Height_Max)];
    CGFloat oldHeight = _inputTextView.frame.size.height;
    CGFloat newHeight = size.height;

    if(newHeight > TTextView_TextView_Height_Max){
        newHeight = TTextView_TextView_Height_Max;
    }
    if(newHeight < TTextView_TextView_Height_Min){
        newHeight = TTextView_TextView_Height_Min;
    }
    if(oldHeight == newHeight){
        return;
    }

    __weak typeof(self) ws = self;
    [UIView animateWithDuration:0.3 animations:^{
        CGRect textFrame = ws.inputTextView.frame;
        textFrame.size.height += newHeight - oldHeight;
        ws.inputTextView.frame = textFrame;
        [ws layoutButton:newHeight + 2 * TTextView_Margin];
    }];
}

- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text
{
    if ([text containsString:@"["] && [text containsString:@"]"] ) {
        NSRange selectedRange = textView.selectedRange;
        if (selectedRange.length > 0) {
            [textView.textStorage deleteCharactersInRange:selectedRange];
        }
    
        NSMutableAttributedString *textChange = [text getAdvancedFormatEmojiStringWithFont:kTUIInputNoramlFont textColor:kTUIInputNormalTextColor emojiLocations:nil];
        [textView.textStorage insertAttributedString:textChange atIndex:textView.textStorage.length];
        dispatch_async(dispatch_get_main_queue(), ^{
            self.inputTextView.selectedRange = NSMakeRange(self.inputTextView.textStorage.length + 1, 0);
        });
        return NO;
    }
    
    if([text isEqualToString:@"\n"]){
        if(_delegate && [_delegate respondsToSelector:@selector(inputBar:didSendText:)]) {
            NSString *sp = [[textView.textStorage getPlainString] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            if (sp.length == 0) {
                UIAlertController *ac = [UIAlertController alertControllerWithTitle:TUIKitLocalizableString(TUIKitInputBlankMessageTitle) message:nil preferredStyle:UIAlertControllerStyleAlert];
                [ac tuitheme_addAction:[UIAlertAction actionWithTitle:TUIKitLocalizableString(Confirm) style:UIAlertActionStyleDefault handler:nil]];
                [self.mm_viewController presentViewController:ac animated:YES completion:nil];
            } else {
                [_delegate inputBar:self didSendText:[textView.textStorage getPlainString]];
                [self clearInput];
            }
        }
        return NO;
    }
    else if ([text isEqualToString:@""]) {
        
        if (textView.textStorage.length > range.location) {
            // 一次性删除 @xxx 这种 @ 消息
            // Delete the @ message like @xxx at one time
            NSAttributedString *lastAttributedStr = [textView.textStorage attributedSubstringFromRange:NSMakeRange(range.location , 1)];
            NSString *lastStr = [lastAttributedStr getPlainString];
            if (lastStr &&  lastStr.length>0 && [lastStr characterAtIndex:0] == ' ') {
                NSUInteger location = range.location;
                NSUInteger length = range.length;
                
                // '@' 对应的ascii码 '@'
                // corresponds to ascii code
                int at = 64;
                // 空格(space) 对应的ascii码
                // Space (space) corresponding ascii code
                int space = 32;
                
                while (location != 0) {
                    location --;
                    length ++ ;
                    // 将字符转成ascii码，复制给int,避免越界
                    // Convert characters to ascii code, copy to int, avoid out of bounds
                    int c = (int)[[[textView.textStorage attributedSubstringFromRange:NSMakeRange(location, 1)] getPlainString] characterAtIndex:0];
                    
                    if (c == at) {
                        NSString *atText = [[textView.textStorage attributedSubstringFromRange:NSMakeRange(location, length)] getPlainString];
                        UIFont *textFont = kTUIInputNoramlFont;
                        NSAttributedString *spaceString = [[NSAttributedString alloc] initWithString:@"" attributes:@{NSFontAttributeName: textFont}];
                        [textView.textStorage replaceCharactersInRange:NSMakeRange(location, length) withAttributedString:spaceString];
                        if (self.delegate && [self.delegate respondsToSelector:@selector(inputBar:didDeleteAt:)]) {
                            [self.delegate inputBar:self didDeleteAt:atText];
                        }
                        return NO;
                    }
                    else if (c == space) {
                        // 避免出现 "@昵称 你好，很高兴认识 你(space)  "" 在空格后按del 过度删除到@
                        // Avoid "@nickname Hello, nice to meet you (space) "" Press del after a space to over-delete to @
                        break;
                    }
                }
            }

        }
    }
    // 监听 @ 字符的输入，包含全角/半角
    // Monitor the input of @ character, including full-width/half-width
    else if ([text isEqualToString:@"@"] || [text isEqualToString:@"＠"]) {
        if (self.delegate && [self.delegate respondsToSelector:@selector(inputBarDidInputAt:)]) {
            [self.delegate inputBarDidInputAt:self];
        }
    }
    return YES;
}

- (void)onDeleteBackward:(TUIResponderTextView_Minimalist *)textView
{
    if (self.delegate && [self.delegate respondsToSelector:@selector(inputBarDidDeleteBackward:)]) {
        [self.delegate inputBarDidDeleteBackward:self];
    }
}

- (void)clearInput
{
    [_inputTextView.textStorage deleteCharactersInRange:NSMakeRange(0, _inputTextView.textStorage.length)];
    [self textViewDidChange:_inputTextView];
}

- (NSString *)getInput
{
    return [_inputTextView.textStorage getPlainString];
}


- (void)addEmoji:(TUIFaceCellData *)emoji
{
    //Create emoji attachment
    TUIEmojiTextAttachment *emojiTextAttachment = [[TUIEmojiTextAttachment alloc] init];
    emojiTextAttachment.faceCellData = emoji;

    NSString *localizableFaceName = emoji.localizableName.length ? emoji.localizableName : emoji.name;

    //Set tag and image
    emojiTextAttachment.emojiTag = localizableFaceName;
    emojiTextAttachment.image =  [[TUIImageCache sharedInstance] getFaceFromCache:emoji.path];
    
    //Set emoji size
    emojiTextAttachment.emojiSize = kChatDefaultEmojiSize;
    NSAttributedString *str = [NSAttributedString attributedStringWithAttachment:emojiTextAttachment];

    NSRange selectedRange = _inputTextView.selectedRange;
    if (selectedRange.length > 0) {
        [_inputTextView.textStorage deleteCharactersInRange:selectedRange];
    }
    //Insert emoji image
    [_inputTextView.textStorage insertAttributedString:str atIndex:_inputTextView.selectedRange.location];
    
    _inputTextView.selectedRange = NSMakeRange(_inputTextView.selectedRange.location+1, 0);
    [self resetTextStyle];

    if(_inputTextView.contentSize.height > TTextView_TextView_Height_Max){
        float offset = _inputTextView.contentSize.height - _inputTextView.frame.size.height;
        [_inputTextView scrollRectToVisible:CGRectMake(0, offset, _inputTextView.frame.size.width, _inputTextView.frame.size.height) animated:YES];
    }
    [self textViewDidChange:_inputTextView];
    
}

- (void)resetTextStyle {
    //After changing text selection, should reset style.
    NSRange wholeRange = NSMakeRange(0, _inputTextView.textStorage.length);

    [_inputTextView.textStorage removeAttribute:NSFontAttributeName range:wholeRange];
    
    [_inputTextView.textStorage removeAttribute:NSForegroundColorAttributeName range:wholeRange];

    [_inputTextView.textStorage addAttribute:NSForegroundColorAttributeName value:kTUIInputNormalTextColor range:wholeRange];

    [_inputTextView.textStorage addAttribute:NSFontAttributeName value:kTUIInputNoramlFont range:wholeRange];
    [_inputTextView setFont:kTUIInputNoramlFont];
}

- (void)backDelete
{

    if (_inputTextView.textStorage.length > 0) {
        [_inputTextView.textStorage deleteCharactersInRange:NSMakeRange(_inputTextView.textStorage.length - 1, 1)];
        [self textViewDidChange:_inputTextView];
    }
    
}

- (void)updateTextViewFrame
{
    [self textViewDidChange:[UITextView new]];
}

- (void)changeToKeyboard
{
    [self clickKeyboardBtn:self.keyboardButton];
}

- (void)onThemeChanged {
    [self applyBorderTheme];
}

#pragma mark - TUIAudioRecorderDelegate
- (void)audioRecorder:(TUIAudioRecorder *)recorder
   didCheckPermission:(BOOL)isGranted
          isFirstTime:(BOOL)isFirstTime {
    if (isFirstTime) {
        if (!isGranted) {
            [self showRequestMicAuthorizationAlert];
        }
        return;
    }
    
    [self setRecordStatus:TUIRecordStatus_Record];
    _recordStartTime = [NSDate date];
    [self showHapticFeedback];
}

- (void)showRequestMicAuthorizationAlert {
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:TUIKitLocalizableString(TUIKitInputNoMicTitle) message:TUIKitLocalizableString(TUIKitInputNoMicTips) preferredStyle:UIAlertControllerStyleAlert];
    [ac tuitheme_addAction:[UIAlertAction actionWithTitle:TUIKitLocalizableString(TUIKitInputNoMicOperateLater) style:UIAlertActionStyleCancel handler:nil]];
    [ac tuitheme_addAction:[UIAlertAction actionWithTitle:TUIKitLocalizableString(TUIKitInputNoMicOperateEnable) style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        UIApplication *app = [UIApplication sharedApplication];
        NSURL *settingsURL = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
        if ([app canOpenURL:settingsURL]) {
            [app openURL:settingsURL];
        }
    }]];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.mm_viewController presentViewController:ac animated:YES completion:nil];
    });
}

- (void)audioRecorder:(TUIAudioRecorder *)recorder didRecordTimeChanged:(NSTimeInterval)time {
    _recordTimeLabel.text = [NSString stringWithFormat:@"%d:%.2d", (int)time / 60, (int)time % 60];
    CGFloat width = _recordAnimateCoverViewFrame.size.width;
    int interval_ms = (int)(time * 1000);
    int runloop_ms = 5 * 1000;
    CGFloat offset_x =  width * (interval_ms % runloop_ms) / runloop_ms;
    _recordAnimateCoverView.frame = CGRectMake(_recordAnimateCoverViewFrame.origin.x + offset_x,
                                               _recordAnimateCoverViewFrame.origin.y,
                                               width - offset_x,
                                               _recordAnimateCoverViewFrame.size.height);
    
    if (time >= 60) {
        [self setRecordStatus:TUIRecordStatus_Cancel];
        [self.recorder stop];
        NSString *path = self.recorder.recordedFilePath;
        if (path) {
            if(_delegate && [_delegate respondsToSelector:@selector(inputBar:didSendVoice:)]){
                [_delegate inputBar:self didSendVoice:path];
            }
        }
    }
}

#pragma mark - Getter
- (TUIAudioRecorder *)recorder {
    if (!_recorder) {
        _recorder = [[TUIAudioRecorder alloc] init];
        _recorder.delegate = self;
    }
    return _recorder;
}

@end
