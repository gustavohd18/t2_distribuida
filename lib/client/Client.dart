import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

import 'package:t2_distribution_programming/ClientToServer.dart';
import 'package:t2_distribution_programming/client/MessageClient.dart';

class Client {
  final String id;
  final String ip;
  final int availablePort;
  List<String> files;
  final Socket socketClient;
  Client(this.id, this.socketClient, this.ip, this.availablePort);

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
              final list = messageObject.data.cast<String>();
              print(list);
            }
            break;

          case 'PROCESSING_REQUEST':
            {
              print('Processando a lista de arquivos na rede');
            }
            break;
          case 'RESPONSE_CLIENT_WITH_DATA':
            {
              final list = messageObject.data['files'].cast<String>();
              final clientObject = ClientToServer(
                messageObject.data['id'],
                messageObject.data['ip'],
                messageObject.data['availablePort'],
                list,
                0
              );
              print('data ${clientObject.ip}  ${clientObject.availablePort}');
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

  void heartbeatClient() async {
    const fiveSec = Duration(seconds: 5);
    Timer.periodic(
        fiveSec,
        (Timer t) =>
            sendMessageStringToSupernodo(MessageClient('HEARTBEAT_CLIENT', id)));
  }

  Future<void> sendMessageStringToSupernodo(MessageClient messageClient) async {
    //vamos usar json nos objetos para envio
    var encodedMessage = jsonEncode(messageClient);
    print('Nodo: $encodedMessage');
    //add delay por enquanto devido a problemas com msg sendo mandadas ao mesmo tempo enquanto nao tem o terminal pronto
    await Future.delayed(Duration(seconds: 2));
    socketClient.write(encodedMessage);
  }
}
