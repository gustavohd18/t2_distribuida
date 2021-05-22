import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:t2_distribution_programming/data/ClientToServer.dart';
import 'package:t2_distribution_programming/data/Message.dart';
import 'package:t2_distribution_programming/data/FileHash.dart';

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
    var filesDir = Directory(filesPath);
    if (filesDir.existsSync()) {
      var hashFileList = List<FileHash>();
      var contents = filesDir.listSync(recursive: false);
      for (File file in contents) {
        var digest = await (sha256.bind(file.openRead())).first;
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
            Message(decodedMessage['message'], decodedMessage['data']);

        switch (messageObject.message) {
          case 'RESPONSE_LIST':
            {
              if (messageObject.data != null) {
                final list = messageObject.data.cast<String>();
                filesComming.clear();
                filesComming.addAll(list);
                print('Lista de arquivos disponiveis:');
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
                //will be return just one single file
                var filehashList = <FileHash>[];
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
                // request file to other client using socket
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
        var sep = Platform.isWindows ? "\\" : "/";
        var fileName = pathFile.split(sep).last;
        // pega os bytes do arquivo para envio
        var bytes = await File(pathFile).openRead();
        await client.addStream(bytes);
        // Finished send bytes
        // we need added a delay to send next message in a single packet
        await Future.delayed(Duration(seconds: 1));
        // this message is used to identify all packet from data was send
        client.write('FINESHED${hash}$fileName');
      },

      // handle errors
      onError: (error) {
        print(error);
        client.close();
      },

      // handle the client closing the connection after send all packet
      onDone: () {
        print('Dados enviados para o nodo');
      },
    );
  }

  void heartbeatClient() async {
    const fiveSec = Duration(seconds: 5);
    Timer.periodic(
        fiveSec,
        (Timer t) =>
            sendMessageStringToSupernodo(Message('HEARTBEAT_CLIENT', id)));
  }

  Future<void> sendMessageStringToSupernodo(Message messageClient) async {
    //parser to json
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
        //get name and extension to file
        final file = File('${patchToSaveFiles}/${fileName[1]}');

        final buffer = dt.buffer;
        await file.writeAsBytesSync(
            buffer.asUint8List(dt.offsetInBytes, dt.lengthInBytes));
        // close socket after save file
        await socket.close();
      } else {
        builder.add(data);
      }
    });
  }

  Future<String> getPathFile(String hash) async {
    if (hashAndFile[hash] != null) {
      print(
          'Recebi uma solicitação de arquivo que se encontra na pasta ${hashAndFile[hash]}');
      return hashAndFile[hash];
    } else {
      return '';
    }
  }
}
