import SwiftUI
import AVFoundation
import Network

class RadioTransmitter: ObservableObject {
    var audioRecorder: AVAudioRecorder?
    var connection: NWConnection?
    @Published var isRecording = false
    @Published var selectedChannel = 1
    var multicastGroup: NWEndpoint.Host
    var port: NWEndpoint.Port

    init(multicastGroup: String, port: UInt16) {
        self.multicastGroup = NWEndpoint.Host(multicastGroup)
        self.port = NWEndpoint.Port(rawValue: port) ?? 12345
        setupConnection()
    }

    func setupConnection() {
        let parameters = NWParameters.udp
        parameters.allowLocalEndpointReuse = true
        connection = NWConnection(host: multicastGroup, port: port, using: parameters)
        connection?.start(queue: .main)
    }

    func startRecording() {
        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setCategory(.playAndRecord, mode: .default)
        try? audioSession.setActive(true)

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 16000.0,
            AVNumberOfChannelsKey: 1
        ]
        
        let url = URL(fileURLWithPath: "/dev/null")
        try? audioRecorder = AVAudioRecorder(url: url, settings: settings)
        audioRecorder?.record()
        isRecording = true
        
        DispatchQueue.global(qos: .background).async {
            while self.isRecording {
                self.sendAudioData()
            }
        }
    }

    func stopRecording() {
        audioRecorder?.stop()
        isRecording = false
    }

    func sendAudioData() {
        guard let audioRecorder = audioRecorder, audioRecorder.isRecording else { return }
        audioRecorder.updateMeters()
        
        if let audioData = audioRecorder.recordedData {
            var channelData = Data()
            channelData.append(Data([UInt8(selectedChannel)]))
            channelData.append(audioData)
            connection?.send(content: channelData, completion: .contentProcessed({ _ in }))
        }
    }
}

struct RadioTransmitterView: View {
    @ObservedObject var radioTransmitter: RadioTransmitter

    var body: some View {
        VStack {
            Text("ProCampus FM")
                .font(.custom("NoteWorthy", size: 34))
                .foregroundColor(.blue)
                .padding()

            Picker("Canal de Envio", selection: $radioTransmitter.selectedChannel) {
                ForEach(1..<8) { channel in
                    Text("Canal \(channel)").tag(channel)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()

            HStack {
                Button(action: {
                    radioTransmitter.startRecording()
                }) {
                    Text("Iniciar Programação")
                        .font(.custom("NoteWorthy", size: 20))
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }

                Button(action: {
                    radioTransmitter.stopRecording()
                }) {
                    Text("Encerrar Programação")
                        .font(.custom("NoteWorthy", size: 20))
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
        }
        .padding()
    }
}
