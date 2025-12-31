import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../core/models/connection_mode.dart';

/// 连接状态
abstract class ConnectionState extends Equatable {
  const ConnectionState();

  @override
  List<Object?> get props => [];
}

/// 连接模式状态
class ConnectionModeState extends ConnectionState {
  final ConnectionMode mode;

  const ConnectionModeState(this.mode);

  @override
  List<Object?> get props => [mode];
}

/// 连接模式 Cubit
class ConnectionModeCubit extends Cubit<ConnectionState> {
  ConnectionModeCubit() : super(const ConnectionModeState(ConnectionMode.rules));

  void changeMode(ConnectionMode mode) {
    emit(ConnectionModeState(mode));
  }
}

