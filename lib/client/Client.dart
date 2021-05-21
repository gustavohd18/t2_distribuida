import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

import 'package:t2_distribution_programming/ClientToServer.dart';
import 'package:t2_distribution_programming/client/MessageClient.dart';

class FilePath {
  final String filename;
  final dynamic path;
  FilePath(this.filename, this.path);

  FilePath.fromJson(Map<String, dynamic> json)
      : filename = json['filename'],
        path = json['path'];

  Map<String, dynamic> toJson() => {
        'filename': filename,
        'path': path,
      };
}

class Client {
  final String id;
  final String ip;
  final int availablePort;
  final String patchToSaveFiles;
  List<String> files;
  final Socket socketClient;
  final ServerSocket socketToReceiveFiles;
  HashMap<String, String> hashAndFile = HashMap<String, String>();
  Client(this.id, this.socketClient, this.ip, this.availablePort,
      this.socketToReceiveFiles, this.patchToSaveFiles);

  Future<List<FileHash>> getHash(filesPath) async {
    /*
   * Fonte(s):
   * https://stackoverflow.com/questions/14268967/how-do-i-list-the-contents-of-a-directory-with-dart
   * https://stackoverflow.com/questions/57385832/flutter-compute-function-for-image-hashing/62202544#62202544
   */
    Directory filesDir = Directory(filesPath);
    if (filesDir.existsSync()) {
      List<FileHash> hashFileList = List<FileHash>();
      List<FileSystemEntity> contents = filesDir.listSync(recursive: false);
      for (File file in contents) {
        Digest digest = await (sha256.bind(file.openRead())).first;
        final sep = Platform.isWindows ? "\\" : "/";
        final fileName = file.path.split(sep).last;
        final filehash = FileHash(fileName, digest.toString());
        hashFileList.add(filehash);
        hashAndFile[digest.toString()] = file.path;
      }
      return hashFileList;
    }
    return null;
  }

  void listenerSupernodo() async {
    print(
        'Conetado com o supernodo: ${socketClient.remoteAddress.address}:${socketClient.remotePort}');

    socketClient.listen(
      (Uint8List data) async {
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
                //pegar o hash como retorno e chamar uma funcao para pegar ele dai
                List<FileHash> filehashList = [];
                final list = messageObject.data['files'];
                for (var i = 0; i < list.length; i++) {
                  var hash = FileHash(list[i]['filename'], list[i]['hash']);
                  print("Cheguei no hash ${hash.fileName} ${hash.hash}");
                  filehashList.add(hash);
                }
                final clientObject = ClientToServer(
                    messageObject.data['id'],
                    messageObject.data['ip'],
                    messageObject.data['availablePort'],
                    filehashList,
                    0);
                print('Enviando arquivo');
                //mock  para teste mas precisa saber como pegar o arquivo  certo para mandar tem que virda solicitacao do user
                //pega somente a primeira posicao que vai ta com o arquivo que o usuario quer
                final filePatch = await getPathFile(filehashList[0].hash);
                sendFile(
                    clientObject.ip, clientObject.availablePort, filePatch);
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
        final object = String.fromCharCodes(data);
        Map<String, dynamic> decodedMessage = jsonDecode(object);
        print(decodedMessage);
        final fileObject =
            FilePath(decodedMessage['filename'], decodedMessage['path']);

        final listu8 = fileObject.path.cast<int>();

        var builder = BytesBuilder(copy: false);
        builder.add(listu8);
        var dt = builder.takeBytes();
        //como pegar o nome do arquivo
        final filename = fileObject.filename;

        await writeToFile(dt.buffer.asByteData(0, dt.buffer.lengthInBytes),
            '$patchToSaveFiles/$filename');
        //fecha o socket depois disso
        await client.close();
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
    String sep = Platform.isWindows ? "\\" : "/";
    String fileName = patchWithFile.split(sep).last;
    print("OLHA O NOME DO ARQUIVO: $fileName");
    final socket = await Socket.connect(ipToSend, port);
    var bytes = await File(patchWithFile).readAsBytes();
    var file = FilePath(fileName, bytes);
    var encodedMessage = jsonEncode(file);
    socket.write(encodedMessage);
  }

  Future<String> getPathFile(String hash) async {
    if (hashAndFile[hash] != null) {
      print('Tenho o patch do arquivo aqui ${hashAndFile[hash]}');
      return hashAndFile[hash];
    } else {
      return '';
    }
  }
}
