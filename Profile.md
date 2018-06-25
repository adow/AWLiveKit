# AWLiveKit Profile

## 总体指标

Phone 6 下面 Profile 的结果

AWLiveSimple

cpu: 10% - 27%
memory: 8.9 - 10.5
energy impact: Low - High/VeryHigh, overhead 50%

AWLiveBeauty

cpu: 38% - 49%
memory: 65 - 65.8
energy impact: Low/VeryHigh - VeryHigh/VeryHigh overhead: 100%

## 各函数时间消耗

AWLivePushC 耗能

- `aw_rtmp_send_h264_video`: 8.7%
	- `RTMP_SendPacket` 841x
		- `send`
- `aw_rtmp_send_audio`: 1.6%
	- `RTMP_SendPacket`: 160x
		- `send`

编码耗能

- `aw_audio_encode`: 4.3%
	- `AudioConverterFillComplexBuffer`: 410x
- `aw_video_encoder_pixelbuffer`: 3.5%
	- `CVPixelBufferLockBaseAddress`: 40x
	- `VTCompressionSessionEncodeFrame`: 283x
	- `CVPixelBufferUnlockBaseAddress`: 21x

在每个线程中的消耗排列

- `aw_rtmp_send_h264_video` 和 `aw_audio_encode/aw_video_encode` 各自要占 8%-8.5%。其中编码部分，音频编码 `aw_audio_encode` 占的更多 4.8% 左右，视频编码部分反而少 3.1%.
- 音频推流 `aw_rtmp_send_audio` 占 2% 左右。

优化方案

- `AWLivePushC` 中的消耗都在 `RTMP_SendPacket/send` 函数，这里很难作出优化了；
- `aw_audio_encode` 编码花费的时间甚至超过视频编码，是否可以修改编码参数。

并没有很好的方法去优化 `aw_audio_encode`，现在使用 `AAC` 音频编码的参数都是固定的了，虽然我可以修改 `bitrate`, 但是仍然没有干删性能。
