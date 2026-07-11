class AppLists {
  static const List<String> prefixOptions = <String>[
    '-',
    'MR',
    'MISS',
    'MRS',
    'SIR',
    'DR',
    'OTHER',
  ];

  static const List<String> monthOptions = <String>[
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  static const List<String> vehicleTypeOptions = <String>[
    'BICYCLE',
    'E-BIKE',
    'MOTORBIKE',
    'SCOOTER',
    'OTHER',
  ];

  static const List<String> countryOptions = <String>[
    '-',
    'UNITED KINGDOM',
    'NORTHERN IRELAND',
  ];

  static const Map<String, List<String>> cityOptionsByCountry =
      <String, List<String>>{
    'UNITED KINGDOM': <String>[
      'ABERDEEN',
      'BATH',
      'BIRMINGHAM',
      'BLACKBURN',
      'BLACKPOOL',
      'BOLTON',
      'BOURNEMOUTH',
      'BRADFORD',
      'BRIGHTON',
      'BRISTOL',
      'CAMBRIDGE',
      'CARDIFF',
      'CHELMSFORD',
      'CHESTER',
      'COLCHESTER',
      'COVENTRY',
      'DERBY',
      'DUNDEE',
      'DURHAM',
      'EDINBURGH',
      'EXETER',
      'GLASGOW',
      'GLOUCESTER',
      'HUDDERSFIELD',
      'HULL',
      'INVERNESS',
      'IPSWICH',
      'LEEDS',
      'LEICESTER',
      'LIVERPOOL',
      'LONDON',
      'LUTON',
      'MANCHESTER',
      'MILTON KEYNES',
      'NEWCASTLE UPON TYNE',
      'NORTHAMPTON',
      'NORWICH',
      'NOTTINGHAM',
      'OXFORD',
      'PETERBOROUGH',
      'PLYMOUTH',
      'PORTSMOUTH',
      'PRESTON',
      'READING',
      'SHEFFIELD',
      'SOUTHAMPTON',
      'STOKE-ON-TRENT',
      'SUNDERLAND',
      'SWANSEA',
      'WOLVERHAMPTON',
      'WORCESTER',
      'YORK',
    ],
    'NORTHERN IRELAND': <String>[
      'ANTRIM',
      'ARMAGH',
      'BALLYMENA',
      'BANGOR',
      'BELFAST',
      'CARRICKFERGUS',
      'COLERAINE',
      'CRAIGAVON',
      'DERRY',
      'ENNISKILLEN',
      'LARNE',
      'LISBURN',
      'NEWRY',
      'NEWTOWNABBEY',
      'NEWTOWNARDS',
      'OMAGH',
      'PORTADOWN',
    ],
  };

  static List<int> buildYearOptions() {
    final int currentYear = DateTime.now().year;
    final int maxAllowedBirthYear = currentYear - 18;
    return List<int>.generate(100, (int index) => maxAllowedBirthYear - index);
  }

  static List<String> cityOptionsForCountry(String? country) {
    if (country == null || country.trim().isEmpty || country == '-') {
      return <String>[];
    }

    return List<String>.from(cityOptionsByCountry[country] ?? <String>[]);
  }
}