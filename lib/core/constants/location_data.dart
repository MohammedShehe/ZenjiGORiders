class LocationData {
  static const List<String> islands = ['Unguja', 'Pemba'];

  static const Map<String, List<String>> regions = {
    'Unguja': [
      'Zanzibar North (Kaskazini Unguja)',
      'Zanzibar South/Central (Kusini/Chake Unguja)',
      'Zanzibar Urban/West (Mjini Magharibi)',
    ],
    'Pemba': [
      'Pemba North (Kaskazini Pemba)',
      'Pemba South (Kusini Pemba)',
    ],
  };

  static const Map<String, List<String>> districts = {
    'Zanzibar North (Kaskazini Unguja)': [
      'North Unguja A (Kaskazini A)',
      'North Unguja B (Kaskazini B)',
    ],
    'Zanzibar South/Central (Kusini/Chake Unguja)': [
      'South Unguja (Kusini)',
      'Central Unguja (Kati)',
    ],
    'Zanzibar Urban/West (Mjini Magharibi)': [
      'Urban (Mjini)',
      'West (Magharibi)',
    ],
    'Pemba North (Kaskazini Pemba)': [
      'Wete',
      'Micheweni',
    ],
    'Pemba South (Kusini Pemba)': [
      'Chake Chake',
      'Mkoani',
    ],
  };

  // Sample wards (Shehia) - comprehensive list for demo
  static const Map<String, List<String>> wards = {
    'North Unguja A (Kaskazini A)': [
      'Nungwi', 'Kendwa', 'Matemwe', 'Pwani Mchangani', 'Kiwengwa', 'Pongwe',
    ],
    'North Unguja B (Kaskazini B)': [
      'Mkokotoni', 'Tumbatu', 'Donge', 'Mahonda', 'Kinyasini',
    ],
    'South Unguja (Kusini)': [
      'Jambiani', 'Paje', 'Bwejuu', 'Makunduchi', 'Kizimkazi', 'Kitogani',
    ],
    'Central Unguja (Kati)': [
      'Uzini', 'Dunga', 'Koani', 'Chwaka', 'Uroa', 'Pingwe',
    ],
    'Urban (Mjini)': [
      'Shangani', 'Malindi', 'Kikwajuni', 'Mkunazini', 'Vuga', 'Kiponda',
      'Mpendae', 'Amani', 'Nyerere', 'Mwembeladu',
    ],
    'West (Magharibi)': [
      'Mwanakwerekwe', 'Fuoni', 'Fuoni Kibondeni', 'Tomondo', 'Kisauni',
      'Bububu', 'Kianga', 'Mwanyanya', 'Chukwani', 'Fumba', 'Bumbwini',
      'Kinuni', 'Mbweni', 'Mtoni', 'Magomeni',
    ],
    'Wete': [
      'Wete', 'Pandani', 'Utaani', 'Kangani', 'Ole', 'Konde',
    ],
    'Micheweni': [
      'Micheweni', 'Wingwi', 'Kinyasini Pemba', 'Msuka', 'Tumbe',
    ],
    'Chake Chake': [
      'Chake Chake', 'Wawi', 'Ngambwa', 'Kilindi', 'Vitongoji',
    ],
    'Mkoani': [
      'Mkoani', 'Chokocho', 'Kangani South', 'Mkanyageni', 'Uweleni',
    ],
  };

  static List<String> getAllWards() {
    final all = <String>[];
    for (final list in wards.values) {
      all.addAll(list);
    }
    return all..sort();
  }
}
