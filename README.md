
##How to use

###0. 準備

- 2台の **BLE対応、iOS7以上** のiOSデバイス（iPhone/iPad）を用意する
- どちらもBluetoothをOnにする


###1. Build & Install

- リモコン側にRemoteVideoControllerをインストール
- 撮影側にRemoteVideoRecorderの方をインストール


###2. リモコン側のLaunch Browserをタップ

- Advertiser #1と出てくる（出てこなかったら、リモコン側のアプリを再起動してください）ので、そこをタップ
- 撮影側に、Acceptするかどうかのアラートビューが出てくるので、Accept

###3. リモコン側で操作

- Start: 撮影開始
- Retake: 撮影中止（リセット）
- Stop: 停止と保存

###Other

- 撮影側に "Start Advertisement" が出てきたらBLE接続が切れてるのでボタンをタップしてadvertiseを再開してください

###ToDo

- リモコン側で撮影ステータスを把握できるようにする
  - 撮影開始
  - 撮影時間
  - 撮影停止
  - プレビュー
- 複数台対応
