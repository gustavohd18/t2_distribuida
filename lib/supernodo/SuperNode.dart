import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:collection';

import 'Messages.dart';

class SuperNode {
  String name;
  HashMap<String, String> peersFiles = HashMap();
  SuperNode(this.name);

  void handleConnectionSocket(Socket client) {
    print('Connection from'
        ' ${client.remoteAddress.address}:${client.remotePort}');

    client.listen(
      (Uint8List data) async {
        final message = String.fromCharCodes(data);
        switch (message) {
          case 'REQUEST_LIST_FILES':
            {
              // mandar requisicao de REQUEST_FILES_PEERS para o multicast
              await sendPackageToMulticast('REQUEST_FILES_PEERS');
              client.write('Solicitacao de arquivos atendidas');
            }
            break;

          case 'REQUEST_PEER':
            {
              client.write('Solicitacao de arquivos atendidas');
            }
            break;

          case 'SEND_FILES_LIST':
            {
              client.write('Solicitacao de arquivos atendidas');
            }
            break;

          default:
            {
              client.write('Nada encontrado com essa solicitacao: ${message}');
            }
            break;
        }
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

  Future<void> sendPackageToMulticast(String message) {
    InternetAddress multicastAddress = new InternetAddress('239.10.10.100');
    int multicastPort = 4545;
    RawDatagramSocket.bind(InternetAddress.ANY_IP_V4, 0)
        .then((RawDatagramSocket s) {
      print("mensagem multicast enviada $message");
      stdout.write("Sending $message  \r");
      s.send('$message\n'.codeUnits, multicastAddress, multicastPort);
    });
  }
}
