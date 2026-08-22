import 'package:flutter/foundation.dart';

@immutable
class WcSessionProposalModel {
  const WcSessionProposalModel({
    required this.id,
    required this.dappName,
    required this.dappUrl,
    this.dappDescription,
    this.dappIcon,
    required this.requestedChains,
    required this.requestedMethods,
    required this.requestedEvents,
    this.isVerified = false,
  });

  final int id;
  final String dappName;
  final String dappUrl;
  final String? dappDescription;
  final String? dappIcon;
  final List<String> requestedChains;
  final List<String> requestedMethods;
  final List<String> requestedEvents;
  final bool isVerified;
}

@immutable
class WcSessionRequestModel {
  const WcSessionRequestModel({
    required this.id,
    required this.topic,
    required this.method,
    required this.chainId,
    required this.dappName,
    required this.dappUrl,
    this.dappIcon,
    required this.params,
    required this.formattedPreview,
  });

  final int id;
  final String topic;
  final String method;
  final String chainId;
  final String dappName;
  final String dappUrl;
  final String? dappIcon;
  final dynamic params;
  final String formattedPreview;
}

@immutable
class WcActiveSessionModel {
  const WcActiveSessionModel({
    required this.topic,
    required this.pairingTopic,
    required this.dappName,
    required this.dappUrl,
    this.dappDescription,
    this.dappIcon,
    required this.chains,
    required this.accounts,
    required this.expiry,
  });

  final String topic;
  final String pairingTopic;
  final String dappName;
  final String dappUrl;
  final String? dappDescription;
  final String? dappIcon;
  final List<String> chains;
  final List<String> accounts;
  final DateTime expiry;

  String get shortTopic {
    if (topic.length <= 12) return topic;
    return '${topic.substring(0, 6)}...${topic.substring(topic.length - 4)}';
  }
}
