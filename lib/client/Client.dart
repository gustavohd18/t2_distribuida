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
  List<String> filesComming = [];
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
        final messageObject =
            MessageClient(decodedMessage['message'], decodedMessage['data']);

        switch (messageObject.message) {
          case 'RESPONSE_LIST':
            {
              if (messageObject.data != null) {
                final list = messageObject.data.cast<String>();
                print('Lista de arquivos disponiveis na rede');
                filesComming.clear();
                filesComming.addAll(list);
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
                  filehashList.add(hash);
                }
                final clientObject = ClientToServer(
                    messageObject.data['id'],
                    messageObject.data['ip'],
                    messageObject.data['availablePort'],
                    filehashList,
                    0);
                print('Enviando Solicitação de arquivo');
                // requisitando o arquivo para o willian informando o hash dele
                sendFile(clientObject.ip, clientObject.availablePort,
                    filehashList[0].hash);
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
        final hash = String.fromCharCodes(data);
        final pathFile = await getPathFile(hash);
        String sep = Platform.isWindows ? "\\" : "/";
        String fileName = pathFile.split(sep).last;
        // pega os bytes do arquivo para envio
        var bytes = await File(pathFile).openRead();
        await client.addStream(bytes);
        // terminei de enviar os bytes
        // envio o nome do arquivo junto com a mensagem de finished
        await Future.delayed(Duration(seconds: 1));
        client.write('FINESHED${hash}$fileName');
      },

      // handle errors
      onError: (error) {
        print(error);
        client.close();
      },

      // handle the client closing the connection
      onDone: () {
        print('Dados enviados para o nodo');
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

  void sendFile(String ipToSend, int port, String hash) async {
    final socket = await Socket.connect(ipToSend, port);
    socket.write(hash);
    var builder = BytesBuilder(copy: false);

    socket.listen((data) async {
      final object = String.fromCharCodes(data);
      if (object.split(hash).contains('FINESHED')) {
        print('DOWNLOAD finalizado');
        final fileName = object.split(hash);
        var dt = builder.takeBytes();
        //como pegar o nome do arquivo
        final file = File('${patchToSaveFiles}/${fileName[1]}');

        final buffer = dt.buffer;
        await file.writeAsBytesSync(
            buffer.asUint8List(dt.offsetInBytes, dt.lengthInBytes));
        await socket.close();
      } else {
        builder.add(data);
      }
    });
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
