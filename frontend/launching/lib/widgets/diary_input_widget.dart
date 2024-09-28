import 'package:daylog_launching/api/api_diary_service.dart';
import 'package:daylog_launching/screens/diary/diary_detail.dart';
import 'package:daylog_launching/screens/footer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:provider/provider.dart';
import 'package:daylog_launching/providers/theme_provider.dart';

class DiaryInputWidget extends StatefulWidget {
  final String titleholder;
  final String contextholder;
  final bool update;
  final int diaryId;
  final String? artImagePath;
  final String date;

  const DiaryInputWidget({
    super.key,
    this.titleholder = '제목',
    this.contextholder = '내용을 입력하세요',
    this.update = false,
    this.diaryId = 1,
    this.artImagePath,
    required this.date,
  });

  @override
  State<DiaryInputWidget> createState() => _InputtextState();
}

class _InputtextState extends State<DiaryInputWidget> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  String? _generatedImagePath;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _titleController =
        TextEditingController(text: widget.update ? widget.titleholder : '');
    _contentController =
        TextEditingController(text: widget.update ? widget.contextholder : '');
  }

  void _submit() async {
    String title = _titleController.text;
    String content = _contentController.text;

    String title2 = _titleController.text.trim();
    String content2 = _contentController.text.trim();

    if (title2.isEmpty || content2.isEmpty) {
      _showErrorDialog('제목과 내용을 모두 입력해주세요.');
      return;
    }

    if (title2.length > 12) {
      _showErrorDialog('제목은 12글자를 초과할 수 없습니다.');
      return;
    }

    setState(() {
      _isLoading = true;
      FocusScope.of(context).unfocus();
    });

    try {
      _generatedImagePath = await ApiDiaryService.getImage(content);
    } catch (e) {
      _showErrorDialog('이미지 생성에 실패했습니다. 다시 시도해주세요.');
      print(e);
      return;
    } finally {
      setState(() {
        _isLoading = false;
      });
    }

    _showCompletionDialog(title, content);
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('오류'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('확인'),
            ),
          ],
        );
      },
    );
  }

  void _showCompletionDialog(String title, String content) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        final screenWidth = MediaQuery.of(context).size.width;
        final screenHeight = MediaQuery.of(context).size.height;
        final themeProvider =
            Provider.of<ThemeProvider>(context, listen: false);

        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15.0),
              ),
              child: Stack(
                children: [
                  Container(
                    width: screenWidth * 0.8,
                    height: screenHeight * 0.5,
                    decoration: BoxDecoration(
                      color: const Color.fromRGBO(237, 237, 237, 10),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Column(
                      children: [
                        SizedBox(
                          height: screenHeight * 0.02,
                        ),
                        Text(
                          widget.update ? '그림을 수정하시겠습니까?' : '그림이 완성되었습니다!',
                          style: TextStyle(
                            fontSize: screenWidth * 0.05,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(
                          height: screenHeight * 0.02,
                        ),
                        Expanded(
                          child: _generatedImagePath != null
                              ? Stack(
                                  children: [
                                    Positioned.fill(
                                      child: Image.network(
                                        _generatedImagePath!,
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                        loadingBuilder:
                                            (context, child, loadingProgress) {
                                          if (loadingProgress == null) {
                                            return child;
                                          } else {
                                            return const Center(
                                              child:
                                                  CircularProgressIndicator(),
                                            );
                                          }
                                        },
                                      ),
                                    ),
                                  ],
                                )
                              : const Image(
                                  image: AssetImage('assets/drawings/2.jpg'),
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                ),
                        ),
                        SizedBox(height: screenHeight * 0.02),
                        Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: screenWidth * 0.05),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              ElevatedButton(
                                onPressed: () async {
                                  if (widget.update) {
                                    setState(() {
                                      _isLoading = true;
                                    });

                                    try {
                                      await ApiDiaryService.updateDiary(
                                        widget.diaryId,
                                        title,
                                        content,
                                        widget.artImagePath!,
                                        widget.date,
                                      );
                                    } catch (e) {
                                      _showErrorDialog('일기 업데이트에 실패했습니다.');
                                      return;
                                    } finally {
                                      setState(() {
                                        _isLoading = false;
                                      });
                                    }

                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => DiaryDetail(
                                          id: widget.diaryId,
                                        ),
                                      ),
                                    );
                                  } else {
                                    Navigator.of(context).pop();
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      const Color.fromRGBO(171, 171, 171, 1),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  minimumSize: Size(
                                      screenWidth * 0.3, screenHeight * 0.05),
                                ),
                                child: Text(
                                  widget.update ? '아니요' : '싫어요',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: screenWidth * 0.04,
                                  ),
                                ),
                              ),
                              ElevatedButton(
                                onPressed: () async {
                                  setState(() {
                                    _isLoading = true;
                                  });

                                  try {
                                    if (widget.update) {
                                      await ApiDiaryService.updateDiary(
                                        widget.diaryId,
                                        title,
                                        content,
                                        _generatedImagePath.toString(),
                                        widget.date,
                                      );
                                    } else {
                                      await ApiDiaryService.saveDiary(
                                        title,
                                        content,
                                        _generatedImagePath.toString(),
                                        widget.date,
                                      );
                                    }
                                  } catch (e) {
                                    _showErrorDialog('일기 저장 또는 업데이트에 실패했습니다.');
                                    print('오류 내용 : $e');
                                    return;
                                  } finally {
                                    setState(() {
                                      _isLoading = false;
                                    });
                                  }

                                  if (widget.update) {
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => DiaryDetail(
                                          id: widget.diaryId,
                                        ),
                                      ),
                                    );
                                  } else {
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) => const Footer(
                                                selectedIndex: 3,
                                              )),
                                    );
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: themeProvider.themeColor,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  minimumSize: Size(
                                      screenWidth * 0.3, screenHeight * 0.05),
                                ),
                                child: _isLoading
                                    ? SpinKitFadingCube(
                                        color: themeProvider.themeColor,
                                        size: screenWidth * 0.06,
                                      )
                                    : Text(
                                        widget.update ? '네' : '좋아요',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: screenWidth * 0.04,
                                        ),
                                      ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: screenHeight * 0.02),
                      ],
                    ),
                  ),
                  if (_isLoading)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Center(
                          child: SpinKitFadingCube(
                            color: themeProvider.themeColor,
                            size: 50.0,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    late Color themeColor;

    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    themeColor = themeProvider.themeColor;

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus(); // 화면을 터치했을 때 키보드를 내림
      },
      child: Stack(
        children: [
          SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: screenWidth * 0.04,
                  vertical: screenHeight * 0.04),
              child: SizedBox(
                height: MediaQuery.of(context).size.height / 2 + bottomInset,
                child: IntrinsicHeight(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: _titleController,
                        decoration: InputDecoration(
                          hintText: widget.titleholder,
                          hintStyle: TextStyle(
                            fontSize: screenWidth * 0.06,
                            color: const Color.fromRGBO(171, 171, 171, 1),
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                        ),
                        style: TextStyle(
                          fontSize: screenWidth * 0.06,
                        ),
                      ),
                      const Divider(),
                      Flexible(
                        child: TextField(
                          controller: _contentController,
                          decoration: InputDecoration(
                            hintText: widget.contextholder,
                            hintStyle: TextStyle(
                              fontSize: screenWidth * 0.05,
                              color: const Color.fromRGBO(171, 171, 171, 1),
                            ),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                          ),
                          style: TextStyle(
                            fontSize: screenWidth * 0.05,
                          ),
                          maxLines: null,
                          keyboardType: TextInputType.multiline,
                        ),
                      ),
                      SizedBox(
                        height: screenHeight * 0.04,
                      ),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: themeColor,
                          minimumSize:
                              Size(screenWidth * 0.8, screenHeight * 0.06),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        child: _isLoading
                            ? SpinKitFadingCube(
                                color: Colors.white,
                                size: screenWidth * 0.06,
                              )
                            : Text(
                                widget.update ? '수정 완료' : '작성 완료',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: screenWidth * 0.05,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_isLoading)
            Positioned.fill(
              child: Container(
                width: screenWidth * 0.5,
                height: screenHeight * 0.4,
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    color: Colors.black54.withOpacity(0.7)),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SpinKitFadingCube(
                      color: themeColor,
                      size: 60.0,
                    ),
                    SizedBox(height: screenHeight * 0.04),
                    Text(
                      "잠시만 기다려주세요!",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: screenWidth * 0.06,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: screenHeight * 0.01),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
