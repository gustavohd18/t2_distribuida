import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

import 'package:t2_distribution_programming/ClientToServer.dart';
import 'package:t2_distribution_programming/client/MessageClient.dart';

class Client {
  final String id;
  final String ip;
  final int availablePort;
  final String patchToSaveFiles;
  List<String> files;
  final Socket socketClient;
  final ServerSocket socketToReceiveFiles;
  Client(this.id, this.socketClient, this.ip, this.availablePort,
      this.socketToReceiveFiles, this.patchToSaveFiles);

  Future<List<String>> getHash(filesPath) async {
    /*
   * Fonte(s):
   * https://stackoverflow.com/questions/14268967/how-do-i-list-the-contents-of-a-directory-with-dart
   * https://stackoverflow.com/questions/57385832/flutter-compute-function-for-image-hashing/62202544#62202544
   */
    Directory filesDir = Directory(filesPath);
    if (filesDir.existsSync()) {
      List<String> hashFileList = List<String>();
      List<FileSystemEntity> contents = filesDir.listSync(recursive: false);
      for (File file in contents) {
        Digest digest = await (sha256.bind(file.openRead())).first;
        hashFileList.add(file.path + ";" + digest.toString());
      }
      return hashFileList;
    }
    return null;
  }

  void listenerSupernodo() async {
    print(
        'Conetado com o supernodo: ${socketClient.remoteAddress.address}:${socketClient.remotePort}');

    socketClient.listen(
      (Uint8List data) {
        final object = String.fromCharCodes(data);
        Map<String, dynamic> decodedMessage = jsonDecode(object);
        print(object);
        final messageObject =
            MessageClient(decodedMessage['message'], decodedMessage['data']);

        switch (messageObject.message) {
          case 'RESPONSE_LIST':
            {
              if (messageObject.data != null) {
                final list = messageObject.data.cast<String>();
                print(list);
              }
            }
            break;

          case 'PROCESSING_REQUEST':
            {
              print('Processando a lista de arquivos na rede');
            }
            break;
          case 'RESPONSE_CLIENT_WITH_DATA':
            {
              if (messageObject.data != null) {
                final list = messageObject.data['files'].cast<String>();
                final clientObject = ClientToServer(
                    messageObject.data['id'],
                    messageObject.data['ip'],
                    messageObject.data['availablePort'],
                    list,
                    0);
                print('data ${clientObject.ip}  ${clientObject.availablePort}');
                //mock  para teste mas precisa saber como pegar o arquivo  certo para mandar tem que virda solicitacao do user
                sendFile(clientObject.ip, clientObject.availablePort,
                    '/Users/gustavoduarte/Desktop/files/ola.txt');
              }
            }
            break;

          case 'REGISTER':
            {
              print('recebido o registro');
            }
            break;

          default:
            print('Nada mapeado');
        }
      },
      onError: (error) {
        print(error);
        socketClient.destroy();
      },
      onDone: () {
        print('Server left.');
        socketClient.destroy();
      },
    );
  }

  void handleConnectionDownload(Socket client) {
    print('Connection from'
        ' ${client.remoteAddress.address}:${client.remotePort}');
    client.listen(
      (Uint8List data) async {
        var builder = BytesBuilder(copy: false);
        builder.add(data);

        var dt = builder.takeBytes();
        //como pegar o nome do arquivo
        final filename = 'ola21.txt';

        await writeToFile(dt.buffer.asByteData(0, dt.buffer.lengthInBytes),
            '$patchToSaveFiles/$filename');
      },

      // handle errors
      onError: (error) {
        print(error);
        client.close();
      },

      // handle the client closing the connection
      onDone: () {
        print('Conexao encerrada supernodo caiu');
        client.close();
      },
    );
  }

  void heartbeatClient() async {
    const fiveSec = Duration(seconds: 5);
    Timer.periodic(
        fiveSec,
        (Timer t) => sendMessageStringToSupernodo(
            MessageClient('HEARTBEAT_CLIENT', id)));
  }

  Future<void> sendMessageStringToSupernodo(MessageClient messageClient) async {
    //vamos usar json nos objetos para envio
    var encodedMessage = jsonEncode(messageClient);
    print('Nodo: $encodedMessage');
    socketClient.write(encodedMessage);
  }

  Future<void> writeToFile(ByteData data, String path) {
    final buffer = data.buffer;
    return File(path).writeAsBytes(
        buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
  }

  void listenerToDownload() async {
    await socketToReceiveFiles.listen((client) {
      handleConnectionDownload(client);
    });
  }

  void sendFile(String ipToSend, int port, String patchWithFile) async {
    final socket = await Socket.connect(ipToSend, port);
    var bytes = await File(patchWithFile).readAsBytes();
    socket.add(bytes);
  }
}
