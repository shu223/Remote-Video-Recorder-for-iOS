
##How to use

###0. 準備

- 2台の **BLE対応、iOS7以上** のiOSデバイス（iPhone/iPad）を用意する
- どちらもBluetoothをOnにする


###1. Build & Install

- リモコン側にRemoteVideoControllerをインストール
- 撮影側にRemoteVideoRecorderの方をインストール


###2. BLE接続

- リモコン側のLaunch Browserをタップ
  - Advertiser #1と出てくるので、そこをタップ
- 撮影側に、Acceptするかどうかのアラートビューが出てくるので、Accept
- リモコン側の表示がconnectedになったらDoneを押してLaunch Browserを閉じる


###3. リモコン側で操作

- Start: 撮影開始
- Retake: 撮影中止（リセット）
- Stop: 停止と保存


###Other

- 撮影側に "Start Advertisement" が出てきたらBLE接続が切れてるのでボタンをタップしてadvertiseを再開してください

###ToDo

- 120fps対応・・・そうなるように実装したつもりだけど **そうなってないっぽい**
- リモコン側で撮影ステータスを把握できるようにする
  - 撮影開始
  - 撮影停止
  - プレビュー
- 複数台対応
