
##How to use

###0. 準備

- 2台の **BLE対応、iOS7以上** のiOSデバイス（iPhone/iPad）を用意する
- どちらもBluetoothをOnにする


###1. Build & Install

- リモコン側にRemoteVideoControllerをインストール
- 撮影側にRemoteVideoRecorderの方をインストール


###2. BLE Pairing

- リモコン側のLaunch Browserをタップ
  - Advertiser #1と出てくるので、そこをタップ
- 撮影側に、Acceptするかどうかのアラートビューが出てくるので、Accept
- リモコン側の表示がconnectedになったらDoneを押してLaunch Browserを閉じる


###3. Video Recording

- 撮影側で所望のFPSをセットしておく
  - FPSは撮影中切り替え不可
  - 120fpsはiPhone5sのみ
- リモコン側で操作


###Other

- 撮影側に "Start Advertisement" が出てきたらBLE接続が切れてるのでボタンをタップしてadvertiseを再開してください

###ToDo

- リモコン側でプレビューできるようにする
- 複数台対応
