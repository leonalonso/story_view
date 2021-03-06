import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_video_player/cached_video_player.dart';
import 'package:flutter/cupertino.dart';

import '../utils.dart';
import '../controller/story_controller.dart';

class VideoLoader {
  String url;

  File videoFile;

  Map<String, dynamic> requestHeaders;

  LoadState state = LoadState.loading;

  VideoLoader(this.url, {this.requestHeaders});

  void loadVideo(VoidCallback onComplete) {
    if (this.videoFile != null) {
      this.state = LoadState.success;
      onComplete();
    }

    final fileStream = DefaultCacheManager()
        .getFileStream(this.url, headers: this.requestHeaders);

    fileStream.listen((fileResponse) {
      if (fileResponse is FileInfo) {
        if (this.videoFile == null) {
          this.state = LoadState.success;
          this.videoFile = fileResponse.file;
          onComplete();
        }
      }
    });
  }
}

class StoryVideo extends StatefulWidget {
  final StoryController storyController;
  final VideoLoader videoLoader;

  StoryVideo(this.videoLoader, {this.storyController, Key key})
      : super(key: key ?? UniqueKey());

  static StoryVideo url(String url,
      {StoryController controller,
      Map<String, dynamic> requestHeaders,
      Key key}) {
    return StoryVideo(
      VideoLoader(url, requestHeaders: requestHeaders),
      storyController: controller,
      key: key,
    );
  }

  @override
  State<StatefulWidget> createState() {
    return StoryVideoState();
  }
}

class StoryVideoState extends State<StoryVideo> {
  Future<void> playerLoader;

  StreamSubscription _streamSubscription;

  CachedVideoPlayerController playerController;

  @override
  void initState() {
    super.initState();

    widget.storyController.pause();

    widget.videoLoader.loadVideo(() {
      if (widget.videoLoader.state == LoadState.success) {
        this.playerController =
            CachedVideoPlayerController.file(widget.videoLoader.videoFile);

        playerController.initialize().then((v) {
          setState(() {});
          widget.storyController.play();
        });

        if (widget.storyController != null) {
          _streamSubscription =
              widget.storyController.playbackNotifier.listen((playbackState) {
            if (playbackState == PlaybackState.pause) {
              playerController.pause();
            } else {
              playerController.play();
            }
          });
        }
      } else {
        setState(() {});
      }
    });
  }

  Widget getContentView() {
    if (widget.videoLoader.state == LoadState.success &&
        playerController.value.initialized) {
      return SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: playerController.value.size?.width ?? 0,
            height: playerController.value.size?.height ?? 0,
            child: ShaderMask(
              shaderCallback: (rect) {
                return LinearGradient(
                  end: Alignment.topCenter,
                  begin: Alignment.bottomCenter,
                  colors: <Color>[
                    Colors.black.withOpacity(1.0),
                    Colors.black.withOpacity(1.0),
                    Colors.black.withOpacity(0.1),
                    Colors.black.withOpacity(0.1),
                  ],
                  stops: [0.75, 0.75, 1.0, 0.5],
                ).createShader(Rect.fromLTRB(0, 0, rect.width, rect.height));
              },
              blendMode: BlendMode.dstIn,
              child: CachedVideoPlayer(playerController),
            ),
          ),
        ),
      );
    }

    return widget.videoLoader.state == LoadState.loading
        ? Center(
              child: CupertinoTheme(
                        data: CupertinoTheme.of(context)
                            .copyWith(brightness: Brightness.dark),
                        child: CupertinoActivityIndicator(
                          radius: 15,
                        ),
                      ),
            )
        : Center(
            child: Text(
            "",
            style: TextStyle(
              color: Colors.white,
            ),
          ));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      height: double.infinity,
      width: double.infinity,
      child: getContentView(),
    );
  }

  @override
  void dispose() {
    playerController.dispose();
    _streamSubscription?.cancel();
    super.dispose();
  }
}
