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

## 使用 AVPreviewLayer 和 CIContext.createCGImage 实现预览的差别

### 在 iPhone 7 下面

使用 CIContext.createCGImage 

- cpu: 20% - 22%
- memory: 27 - 28 MB

使用 AVPreviewLayer 

- cpu: 20% - 23%
- memory: 18.7MB

Energy Impact 无法测量

### 在 iPhone 6 下面

使用 CIContext.createCGImage

- cpu: 25% - 30%
- memory: 15.4 MB
- Energy Impact: Low

使用 AVPreviewLayer

- cpu: 19%
- memory: 11.6 MB
- Energy Impact: Low

所以在 iPhone 6 下面，使用 CIContext 比使用 AVPreviewLayer 要多消耗 10% 左右的 CPU，但是在 iPhone 7 下面其实差不多。

## GPUImage 美颜滤镜的消耗 

GPUImageBeautyFilter 

并没有给性能带来太多的影响，而且发现关闭滤镜后会消耗更多的内存（没有研究），打开滤镜并没消耗更多的 CPU,GPU,电池，因为本身的消耗就比 AVFoundation 的要高一点。不管修改什么参数，对于性能总没有太大的变化，开在第二档会比较好点。

YUGPUImageHighPassSkinSmoothingFilter

他的美颜效果还不如 GPUImageBeauthFilter，而且修改参数后可以看到在 iPhone 6 上有明显的丢帧现象。虽然看上去 CPU, GPU,内存并没有明显的消耗。

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
