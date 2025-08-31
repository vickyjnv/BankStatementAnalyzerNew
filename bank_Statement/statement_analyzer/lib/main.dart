import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:statement_analyzer/firebase_options.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bank Statement Analyzer',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        fontFamily: 'Inter',
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.grey[100],
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasData) {
          return const HomeScreen();
        }
        return const LoginScreen();
      },
    );
  }
}

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  Future<void> _signInWithGoogle(BuildContext context) async {
    try {
      if (kIsWeb) {
        GoogleAuthProvider googleProvider = GoogleAuthProvider();
        await FirebaseAuth.instance.signInWithPopup(googleProvider);
      } else {
        final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
        if (googleUser == null) return;
        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;
        final OAuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        await FirebaseAuth.instance.signInWithCredential(credential);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to sign in with Google: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.indigo.shade300, Colors.purple.shade300],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Card(
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Statement Analyzer',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Your financial insights, simplified.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    icon: const FaIcon(
                      FontAwesomeIcons.google,
                      color: Colors.red,
                    ),
                    label: const Text('Sign in with Google'),
                    onPressed: () => _signInWithGoogle(context),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.black87,
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Statement Analyzer'),
        backgroundColor: Colors.white,
        elevation: 1,
        actions: [
          if (user != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Chip(
                avatar: user.photoURL != null
                    ? CircleAvatar(
                        backgroundImage: NetworkImage(user.photoURL!),
                      )
                    : null,
                label: Text(user.displayName ?? 'No Name'),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await GoogleSignIn().signOut();
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Post Office'),
            Tab(text: 'SBI'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          BankDataScreen(bankType: 'ipbp'),
          BankDataScreen(bankType: 'sbi'),
        ],
      ),
    );
  }
}

// Helper functions moved outside the state to be accessible by DataGridSource
DateTime? _parseDate(String? dateStr) {
  if (dateStr == null) return null;
  try {
    return DateFormat('dd-MMM-yy').parse(dateStr);
  } catch (_) {}
  try {
    return DateFormat('dd/MM/yyyy').parse(dateStr);
  } catch (_) {}
  return null;
}

String _formatDate(dynamic dateValue) {
  if (dateValue == null) return '';
  if (dateValue is Timestamp) {
    return DateFormat('dd-MMM-yy').format(dateValue.toDate());
  }
  final date = _parseDate(dateValue.toString());
  return date != null
      ? DateFormat('dd-MMM-yy').format(date)
      : dateValue.toString();
}

class TransactionDataGridSource extends DataGridSource {
  TransactionDataGridSource({
    required List<Map<String, dynamic>> transactions,
    required String bankType,
  }) {
    _transactions = transactions;
    _bankType = bankType;
    _dataGridRows = _transactions.map<DataGridRow>((transaction) {
      final isIpbp = _bankType == 'ipbp';
      final parsed = transaction['parsed'] as Map<String, dynamic>? ?? {};
      return DataGridRow(
        cells: [
          DataGridCell<String>(
            columnName: 'Date',
            value: _formatDate(transaction[isIpbp ? 'DATE' : 'date']),
          ),
          DataGridCell<String>(
            columnName: isIpbp
                ? 'Original Particulars'
                : 'Original Description',
            value:
                transaction[isIpbp ? 'TRANSACTION PARTICULARS' : 'description']
                    ?.toString(),
          ),
          DataGridCell<String>(
            columnName: 'Parsed Particulars',
            value:
                parsed['name']?.toString() ?? parsed['description']?.toString(),
          ),
          DataGridCell<String>(
            columnName: 'Category',
            value: parsed['category']?.toString(),
          ),
          DataGridCell<String>(
            columnName: 'Sub-Category',
            value: parsed['subCategory']?.toString(),
          ),
          DataGridCell<String>(
            columnName: 'VPA',
            value: parsed['vpa']?.toString(),
          ),
          DataGridCell<double>(
            columnName: 'Debit',
            value:
                double.tryParse(
                  transaction[isIpbp ? 'WITHDRWAL' : 'debit']?.toString() ??
                      '0',
                ) ??
                0,
          ),
          DataGridCell<double>(
            columnName: 'Credit',
            value:
                double.tryParse(
                  transaction[isIpbp ? 'DEPOSIT' : 'credit']?.toString() ?? '0',
                ) ??
                0,
          ),
          DataGridCell<double>(
            columnName: 'Balance',
            value:
                double.tryParse(
                  transaction[isIpbp ? 'BALANCE' : 'balance']?.toString() ??
                      '0',
                ) ??
                0,
          ),
        ],
      );
    }).toList();
  }

  late List<Map<String, dynamic>> _transactions;
  late String _bankType;
  List<DataGridRow> _dataGridRows = [];

  @override
  List<DataGridRow> get rows => _dataGridRows;

  Map<String, dynamic> getTransactionAt(int index) => _transactions[index];

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    final int rowIndex = rows.indexOf(row);
    final transaction = _transactions[rowIndex];
    final parsed = transaction['parsed'] as Map<String, dynamic>? ?? {};
    final subCategory = parsed['subCategory']?.toString() ?? 'N/A';

    return DataGridRowAdapter(
      cells: row.getCells().map<Widget>((dataGridCell) {
        final String columnName = dataGridCell.columnName;
        final cellValue = dataGridCell.value;

        Widget buildCell(
          dynamic value, {
          Color? color,
          TextAlign align = TextAlign.left,
          bool isChip = false,
          String? chipText,
        }) {
          return Container(
            alignment: align == TextAlign.right
                ? Alignment.centerRight
                : Alignment.centerLeft,
            padding: const EdgeInsets.all(8.0),
            child: isChip
                ? Chip(
                    label: Text(chipText ?? ''),
                    backgroundColor:
                        chipText == 'N/A' || chipText == 'Uncategorized'
                        ? Colors.grey.shade300
                        : Colors.blue.shade100,
                    padding: EdgeInsets.zero,
                  )
                : Text(
                    value?.toString() ?? '',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: color),
                  ),
          );
        }

        switch (columnName) {
          case 'Sub-Category':
            return buildCell(null, isChip: true, chipText: subCategory);
          case 'Debit':
            return buildCell(
              '₹${(cellValue as double).toStringAsFixed(2)}',
              color: Colors.red.shade700,
              align: TextAlign.right,
            );
          case 'Credit':
            return buildCell(
              '₹${(cellValue as double).toStringAsFixed(2)}',
              color: Colors.green.shade700,
              align: TextAlign.right,
            );
          case 'Balance':
            return buildCell(
              '₹${(cellValue as double).toStringAsFixed(2)}',
              align: TextAlign.right,
            );
          default:
            return buildCell(cellValue);
        }
      }).toList(),
    );
  }
}

enum TimeAggregation { daily, monthly, yearly }

enum SpendingOverTimeChartType { stackedBar, multiLine }

class BankDataScreen extends StatefulWidget {
  final String bankType;
  const BankDataScreen({super.key, required this.bankType});

  @override
  _BankDataScreenState createState() => _BankDataScreenState();
}

enum ChartType { pie, bar, line }

class _BankDataScreenState extends State<BankDataScreen> {
  List<Map<String, dynamic>> _allTransactions = [];
  List<Map<String, dynamic>> _filteredTransactions = [];
  List<Map<String, dynamic>> _paginatedTransactions = [];
  Set<String> _uniqueTransactionKeys = {};
  List<String> _subCategories = [];
  bool _isLoading = true;
  int _currentPage = 0;
  int _rowsPerPage = 20;
  final List<int> _rowsPerPageOptions = [10, 20, 50, 100];
  int? _sortColumnIndex;
  bool _sortAscending = true;
  late Map<String, bool> _columnVisibility;
  late final List<String> _allPossibleColumns;
  late Map<String, ChartType> _chartTypes;
  TimeAggregation _spendingOverTimeAggregation = TimeAggregation.monthly;
  SpendingOverTimeChartType _spendingOverTimeChartType =
      SpendingOverTimeChartType.stackedBar;

  String? _selectedYear,
      _selectedMonth,
      _selectedDay,
      _selectedCategory,
      _selectedSubCategory,
      _selectedType;

  late TransactionDataGridSource _dataGridSource;

  @override
  void initState() {
    super.initState();
    _chartTypes = {
      'spendingByCategory': ChartType.pie,
      'incomeByCategory': ChartType.pie,
      'spendingBySubCategory': ChartType.bar,
      'spendingByVpa': ChartType.bar,
      'spendingByParticulars': ChartType.bar,
    };
    _allPossibleColumns = [
      'Date',
      widget.bankType == 'ipbp'
          ? 'Original Particulars'
          : 'Original Description',
      'Parsed Particulars',
      'Category',
      'Sub-Category',
      'VPA',
      'Debit',
      'Credit',
      'Balance',
    ];
    _columnVisibility = {for (var col in _allPossibleColumns) col: true};
    _dataGridSource = TransactionDataGridSource(
      transactions: [],
      bankType: widget.bankType,
    );
    _fetchInitialData();
  }

  Future<void> _fetchInitialData() async {
    setState(() => _isLoading = true);
    await _fetchSubCategories();
    await _fetchTransactions();
  }

  Future<void> _fetchSubCategories() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('artifacts')
        .doc('default-app-id')
        .collection('public')
        .doc('data')
        .collection('sub_categories')
        .get();
    setState(() {
      _subCategories =
          snapshot.docs.map((doc) => doc.data()['name'] as String).toList()
            ..sort();
    });
  }

  Future<void> _fetchTransactions() async {
    setState(() => _isLoading = true);
    final userId = FirebaseAuth.instance.currentUser!.uid;
    final collectionName = '${widget.bankType}_transactions';
    final snapshot = await FirebaseFirestore.instance
        .collection('artifacts')
        .doc('default-app-id')
        .collection('users')
        .doc(userId)
        .collection(collectionName)
        .orderBy('timestamp', descending: true)
        .get();

    final transactions = snapshot.docs.map((doc) {
      var data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();

    final uniqueKeys = transactions.map(_generateUniqueKey).toSet();

    setState(() {
      _allTransactions = transactions;
      _uniqueTransactionKeys = uniqueKeys;
      _isLoading = false;
    });
    _applyFilters();
  }

  void _applyFilters() {
    List<Map<String, dynamic>> filtered = List.from(_allTransactions);
    if (_selectedYear != null)
      filtered = filtered
          .where(
            (t) =>
                _parseDate(
                  t['DATE']?.toString() ?? t['date']?.toString(),
                )?.year.toString() ==
                _selectedYear,
          )
          .toList();
    if (_selectedMonth != null)
      filtered = filtered
          .where(
            (t) =>
                _parseDate(
                  t['DATE']?.toString() ?? t['date']?.toString(),
                )?.month.toString() ==
                _selectedMonth,
          )
          .toList();
    if (_selectedDay != null)
      filtered = filtered
          .where(
            (t) =>
                _parseDate(
                  t['DATE']?.toString() ?? t['date']?.toString(),
                )?.day.toString() ==
                _selectedDay,
          )
          .toList();
    if (_selectedCategory != null)
      filtered = filtered
          .where((t) => t['parsed']?['category'] == _selectedCategory)
          .toList();
    if (_selectedSubCategory != null)
      filtered = filtered
          .where((t) => t['parsed']?['subCategory'] == _selectedSubCategory)
          .toList();
    if (_selectedType == 'Credit')
      filtered = filtered
          .where(
            (t) =>
                (double.tryParse(
                      t['DEPOSIT']?.toString() ??
                          t['credit']?.toString() ??
                          '0',
                    ) ??
                    0) >
                0,
          )
          .toList();
    if (_selectedType == 'Debit')
      filtered = filtered
          .where(
            (t) =>
                (double.tryParse(
                      t['WITHDRWAL']?.toString() ??
                          t['debit']?.toString() ??
                          '0',
                    ) ??
                    0) >
                0,
          )
          .toList();
    _filteredTransactions = filtered;
    _currentPage = 0;
    _paginateTransactions();
  }

  void _paginateTransactions() {
    setState(() {
      final startIndex = _currentPage * _rowsPerPage;
      final endIndex =
          (startIndex + _rowsPerPage > _filteredTransactions.length)
          ? _filteredTransactions.length
          : startIndex + _rowsPerPage;
      _paginatedTransactions = (startIndex >= _filteredTransactions.length)
          ? []
          : _filteredTransactions.sublist(startIndex, endIndex);
      _dataGridSource = TransactionDataGridSource(
        transactions: _paginatedTransactions,
        bankType: widget.bankType,
      );
    });
  }

  String _generateUniqueKey(Map<String, dynamic> t) {
    if (widget.bankType == 'ipbp')
      return [
        (t['parsed']?['upiId'] ?? 'N/A').toString(),
        (t['DATE'] ?? '').toString(),
        (t['TRANSACTION PARTICULARS'] ?? '').toString(),
        (double.tryParse(t['BALANCE']?.toString() ?? '0') ?? 0).toStringAsFixed(
          2,
        ),
      ].join('|');
    return [
      (t['date'] ?? '').toString(),
      (t['description'] ?? '').toString(),
      (double.tryParse(t['debit']?.toString() ?? '0') ?? 0).toString(),
      (double.tryParse(t['credit']?.toString() ?? '0') ?? 0).toString(),
      (double.tryParse(t['balance']?.toString() ?? '0') ?? 0).toString(),
    ].join('|');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _allTransactions.isEmpty
          ? const Center(child: Text('No transactions found.'))
          : RefreshIndicator(
              onRefresh: _fetchTransactions,
              child: ListView(
                padding: const EdgeInsets.all(8),
                children: [
                  _buildFilterPanel(),
                  const SizedBox(height: 8),
                  _buildDashboard(),
                  const SizedBox(height: 8),
                  _buildTransactionGrid(),
                ],
              ),
            ),
    );
  }

  Widget _buildFilterPanel() {
    final years =
        _allTransactions
            .map(
              (t) => _parseDate(
                t['DATE']?.toString() ?? t['date']?.toString(),
              )?.year.toString(),
            )
            .where((y) => y != null)
            .toSet()
            .toList()
          ..sort();
    final categories = _allTransactions
        .map((t) => t['parsed']?['category']?.toString())
        .where((c) => c != null)
        .toSet()
        .toList();
    final subCategories =
        _allTransactions
            .map((t) => t['parsed']?['subCategory']?.toString())
            .where((sc) => sc != null && sc != 'N/A' && sc != 'Uncategorized')
            .toSet()
            .toList()
          ..sort();

    return Card(
      child: Column(
        children: [
          ExpansionTile(
            title: const Text("Filters"),
            leading: const Icon(Icons.filter_list),
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    _buildFilterDropdown(
                      label: "Year",
                      value: _selectedYear,
                      items: years.whereType<String>().toList(),
                      onChanged: (val) => setState(() => _selectedYear = val),
                    ),
                    _buildFilterDropdown(
                      label: "Month",
                      value: _selectedMonth,
                      items: List.generate(12, (i) => (i + 1).toString()),
                      onChanged: (val) => setState(() => _selectedMonth = val),
                    ),
                    _buildFilterDropdown(
                      label: "Day",
                      value: _selectedDay,
                      items: List.generate(31, (i) => (i + 1).toString()),
                      onChanged: (val) => setState(() => _selectedDay = val),
                    ),
                    _buildFilterDropdown(
                      label: "Category",
                      value: _selectedCategory,
                      items: categories.whereType<String>().toList(),
                      onChanged: (val) =>
                          setState(() => _selectedCategory = val),
                    ),
                    _buildFilterDropdown(
                      label: "Sub-Category",
                      value: _selectedSubCategory,
                      items: subCategories.whereType<String>().toList(),
                      onChanged: (val) =>
                          setState(() => _selectedSubCategory = val),
                    ),
                    _buildFilterDropdown(
                      label: "Type",
                      value: _selectedType,
                      items: ['Credit', 'Debit'],
                      onChanged: (val) => setState(() => _selectedType = val),
                    ),
                  ],
                ),
              ),
            ],
          ), // Comma added here to separate widgets in the Column
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.view_column_outlined),
                  label: const Text("Manage Columns"),
                  onPressed: _showColumnVisibilityDialog,
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedYear = null;
                      _selectedMonth = null;
                      _selectedDay = null;
                      _selectedCategory = null;
                      _selectedSubCategory = null;
                      _selectedType = null;
                    });
                    _applyFilters();
                  },
                  child: const Text("Clear"),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _applyFilters,
                  child: const Text("Apply"),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown({
    required String label,
    String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      items: items
          .map((item) => DropdownMenuItem(value: item, child: Text(item)))
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildDashboard() => LayoutBuilder(
    builder: (context, constraints) => constraints.maxWidth > 800
        ? _buildWideDashboard()
        : _buildNarrowDashboard(),
  );
  Widget _buildWideDashboard() {
    final isIpbp = widget.bankType == 'ipbp';
    return Column(
      children: [
        Row(
          children: [
            Expanded(flex: 1, child: _buildStatsAndTrendCard()),
            const SizedBox(width: 8),
            Expanded(flex: 1, child: _buildSpendingByCategoryCard()),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 1, child: _buildIncomeByCategoryCard()),
            const SizedBox(width: 8),
            Expanded(flex: 1, child: _buildSpendingBySubCategoryCard()),
          ],
        ),
        const SizedBox(height: 8),
        _buildSpendingOverTimeCard(),
        const SizedBox(height: 8),
        isIpbp ? _buildSpendingByVpaCard() : _buildSpendingByParticularsCard(),
      ],
    );
  }

  Widget _buildNarrowDashboard() => Column(
    children: [
      _buildStatsAndTrendCard(),
      const SizedBox(height: 8),
      _buildSpendingOverTimeCard(),
      const SizedBox(height: 8),
      _buildSpendingByCategoryCard(),
      const SizedBox(height: 8),
      _buildIncomeByCategoryCard(),
      const SizedBox(height: 8),
      _buildSpendingBySubCategoryCard(),
      const SizedBox(height: 8),
      widget.bankType == 'ipbp'
          ? _buildSpendingByVpaCard()
          : _buildSpendingByParticularsCard(),
    ],
  );

  Widget _buildSpendingOverTimeCard() {
    final chartData = _calculateSpendingOverTimeData();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Spending Over Time by Sub-Category',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              children: [
                SegmentedButton<TimeAggregation>(
                  segments: const <ButtonSegment<TimeAggregation>>[
                    ButtonSegment<TimeAggregation>(
                      value: TimeAggregation.daily,
                      label: Text('Daily'),
                    ),
                    ButtonSegment<TimeAggregation>(
                      value: TimeAggregation.monthly,
                      label: Text('Monthly'),
                    ),
                    ButtonSegment<TimeAggregation>(
                      value: TimeAggregation.yearly,
                      label: Text('Yearly'),
                    ),
                  ],
                  selected: {_spendingOverTimeAggregation},
                  onSelectionChanged: (Set<TimeAggregation> newSelection) {
                    setState(() {
                      _spendingOverTimeAggregation = newSelection.first;
                    });
                  },
                ),
                SegmentedButton<SpendingOverTimeChartType>(
                  segments: const <ButtonSegment<SpendingOverTimeChartType>>[
                    ButtonSegment<SpendingOverTimeChartType>(
                      value: SpendingOverTimeChartType.stackedBar,
                      icon: Icon(Icons.stacked_bar_chart),
                    ),
                    ButtonSegment<SpendingOverTimeChartType>(
                      value: SpendingOverTimeChartType.multiLine,
                      icon: Icon(Icons.stacked_line_chart),
                    ),
                  ],
                  selected: {_spendingOverTimeChartType},
                  onSelectionChanged:
                      (Set<SpendingOverTimeChartType> newSelection) {
                        setState(() {
                          _spendingOverTimeChartType = newSelection.first;
                        });
                      },
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 400,
              child: chartData.isEmpty
                  ? const Center(child: Text("No spending data for this view."))
                  : _buildSpendingOverTimeChart(chartData),
            ),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _calculateSpendingOverTimeData() {
    Map<String, Map<String, double>> aggregatedData =
        {}; // Key: time period, Value: {subCategory: amount}
    String Function(DateTime) timeKeyFormatter;

    switch (_spendingOverTimeAggregation) {
      case TimeAggregation.daily:
        timeKeyFormatter = (date) => DateFormat('yyyy-MM-dd').format(date);
        break;
      case TimeAggregation.monthly:
        // Use a sortable format for the key, which will be formatted for display later.
        timeKeyFormatter = (date) => DateFormat('yyyy-MM').format(date);
        break;
      case TimeAggregation.yearly:
        timeKeyFormatter = (date) => DateFormat('yyyy').format(date);
        break;
    }

    for (var t in _filteredTransactions) {
      final debit =
          double.tryParse(
            t['WITHDRWAL']?.toString() ?? t['debit']?.toString() ?? '0',
          ) ??
          0;
      if (debit > 0) {
        final date = _parseDate(t['DATE']?.toString() ?? t['date']?.toString());
        if (date != null) {
          final timeKey = timeKeyFormatter(date);
          final subCategory =
              t['parsed']?['subCategory']?.toString() ?? 'Uncategorized';
          if (subCategory != 'N/A') {
            aggregatedData.putIfAbsent(timeKey, () => {});
            aggregatedData[timeKey]![subCategory] =
                (aggregatedData[timeKey]![subCategory] ?? 0) + debit;
          }
        }
      }
    }

    final sortedKeys = aggregatedData.keys.toList()..sort();

    final allSubCategories = aggregatedData.values
        .expand((subCategoryMap) => subCategoryMap.keys)
        .toSet();

    return sortedKeys.map((timeKey) {
      String displayTimeKey;
      if (_spendingOverTimeAggregation == TimeAggregation.monthly) {
        try {
          // Parse 'yyyy-MM' and format to 'MMM yyyy' for display
          final date = DateFormat('yyyy-MM').parse(timeKey);
          displayTimeKey = DateFormat('MMM yyyy').format(date);
        } catch (e) {
          displayTimeKey = timeKey; // Fallback in case of parsing error
        }
      } else {
        displayTimeKey = timeKey;
      }
      final entry = <String, dynamic>{'time': displayTimeKey};
      for (var subCategory in allSubCategories) {
        entry[subCategory] = aggregatedData[timeKey]![subCategory] ?? 0.0;
      }
      return entry;
    }).toList();
  }

  Widget _buildSpendingOverTimeChart(List<Map<String, dynamic>> chartData) {
    if (chartData.isEmpty) return const SizedBox.shrink();

    final subCategories = chartData.first.keys
        .where((k) => k != 'time')
        .toList();

    List<CartesianSeries<Map<String, dynamic>, String>> seriesList = [];

    if (_spendingOverTimeChartType == SpendingOverTimeChartType.stackedBar) {
      seriesList = subCategories.map((subCategory) {
        return StackedColumnSeries<Map<String, dynamic>, String>(
          dataSource: chartData,
          xValueMapper: (data, _) => data['time'] as String,
          yValueMapper: (data, _) => data[subCategory],
          name: subCategory,
        );
      }).toList();
    } else {
      // multiLine
      seriesList = subCategories.map((subCategory) {
        return LineSeries<Map<String, dynamic>, String>(
          dataSource: chartData,
          xValueMapper: (data, _) => data['time'] as String,
          yValueMapper: (data, _) => data[subCategory],
          name: subCategory,
          markerSettings: const MarkerSettings(
            isVisible: true,
            height: 4,
            width: 4,
          ),
        );
      }).toList();
    }

    return ClipRect(
      child: SfCartesianChart(
        palette: _chartColors,
        primaryXAxis: CategoryAxis(
          labelIntersectAction: AxisLabelIntersectAction.rotate90,
          interval: 1,
          majorGridLines: const MajorGridLines(width: 0),
        ),
        primaryYAxis: NumericAxis(numberFormat: NumberFormat.decimalPattern()),
        tooltipBehavior: TooltipBehavior(enable: true, shared: true),
        legend: const Legend(
          isVisible: true,
          overflowMode: LegendItemOverflowMode.wrap,
          position: LegendPosition.bottom,
        ),
        series: seriesList,
        zoomPanBehavior: ZoomPanBehavior(
          enablePinching: true,
          enablePanning: true,
          enableSelectionZooming: true,
          zoomMode: ZoomMode.x,
        ),
      ),
    );
  }

  Widget _buildStatsAndTrendCard() {
    double totalCredit = _filteredTransactions.fold(
      0,
      (sum, t) =>
          sum +
          (double.tryParse(
                t['DEPOSIT']?.toString() ?? t['credit']?.toString() ?? '0',
              ) ??
              0),
    );
    double totalDebit = _filteredTransactions.fold(
      0,
      (sum, t) =>
          sum +
          (double.tryParse(
                t['WITHDRWAL']?.toString() ?? t['debit']?.toString() ?? '0',
              ) ??
              0),
    );
    Map<String, double> monthlySpending = {};
    for (var t in _filteredTransactions) {
      final debit =
          double.tryParse(
            t['WITHDRWAL']?.toString() ?? t['debit']?.toString() ?? '0',
          ) ??
          0;
      if (debit > 0) {
        final date = _parseDate(t['DATE']?.toString() ?? t['date']?.toString());
        if (date != null) {
          final monthKey = DateFormat('yyyy-MM').format(date);
          monthlySpending[monthKey] = (monthlySpending[monthKey] ?? 0) + debit;
        }
      }
    }
    final sortedMonths = monthlySpending.keys.toList()..sort();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Overview',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatCard(
                  'Transactions',
                  _filteredTransactions.length.toString(),
                ),
                _buildStatCard(
                  'Total Credit',
                  '₹${totalCredit.toStringAsFixed(2)}',
                  color: Colors.green.shade700,
                ),
                _buildStatCard(
                  'Total Debit',
                  '₹${totalDebit.toStringAsFixed(2)}',
                  color: Colors.red.shade700,
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'Monthly Spending Trend',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: sortedMonths.isEmpty
                  ? const Center(
                      child: Text("No spending data for trend chart."),
                    )
                  : SfCartesianChart(
                      primaryXAxis: CategoryAxis(),
                      primaryYAxis: NumericAxis(
                        numberFormat: NumberFormat.decimalPattern(),
                      ),
                      tooltipBehavior: TooltipBehavior(enable: true),
                      series:
                          <CartesianSeries<MapEntry<String, double>, String>>[
                            LineSeries<MapEntry<String, double>, String>(
                              dataSource: monthlySpending.entries.toList()
                                ..sort((a, b) => a.key.compareTo(b.key)),
                              xValueMapper: (entry, _) => entry.key,
                              yValueMapper: (entry, _) => entry.value,
                              name: 'Spending',
                            ),
                          ],
                      zoomPanBehavior: ZoomPanBehavior(
                        enablePinching: true,
                        enablePanning: true,
                        enableSelectionZooming: true,
                        zoomMode: ZoomMode.x,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  final List<Color> _chartColors = [
    Colors.indigo.shade400,
    Colors.teal.shade400,
    Colors.amber.shade600,
    Colors.pink.shade400,
    Colors.green.shade500,
    Colors.orange.shade500,
    Colors.purple.shade400,
    Colors.cyan.shade500,
    Colors.red.shade400,
    Colors.blue.shade500,
  ];

  Map<String, double> _calculateSpendingByCategory() {
    Map<String, double> data = {};
    for (var t in _filteredTransactions) {
      final debit =
          double.tryParse(
            t['WITHDRWAL']?.toString() ?? t['debit']?.toString() ?? '0',
          ) ??
          0;
      if (debit > 0) {
        final category = t['parsed']?['category']?.toString() ?? 'Other';
        data[category] = (data[category] ?? 0) + debit;
      }
    }
    return data;
  }

  Map<String, double> _calculateIncomeByCategory() {
    Map<String, double> data = {};
    for (var t in _filteredTransactions) {
      final credit =
          double.tryParse(
            t['DEPOSIT']?.toString() ?? t['credit']?.toString() ?? '0',
          ) ??
          0;
      if (credit > 0) {
        final category = t['parsed']?['category']?.toString() ?? 'Other';
        data[category] = (data[category] ?? 0) + credit;
      }
    }
    return data;
  }

  Map<String, double> _calculateSpendingBySubCategory() {
    Map<String, double> data = {};
    for (var t in _filteredTransactions) {
      final debit =
          double.tryParse(
            t['WITHDRWAL']?.toString() ?? t['debit']?.toString() ?? '0',
          ) ??
          0;
      if (debit > 0) {
        final subCategory =
            t['parsed']?['subCategory']?.toString() ?? 'Uncategorized';
        if (subCategory != 'N/A') {
          data[subCategory] = (data[subCategory] ?? 0) + debit;
        }
      }
    }
    return data;
  }

  Map<String, double> _calculateSpendingByVpa() {
    Map<String, double> data = {};
    for (var t in _filteredTransactions) {
      final debit = double.tryParse(t['WITHDRWAL']?.toString() ?? '0') ?? 0;
      if (debit > 0) {
        final vpa = t['parsed']?['vpa']?.toString();
        if (vpa != null && vpa != 'N/A') {
          data[vpa] = (data[vpa] ?? 0) + debit;
        }
      }
    }
    return data;
  }

  Map<String, double> _calculateSpendingByParticulars() {
    Map<String, double> data = {};
    for (var t in _filteredTransactions) {
      final debit = double.tryParse(t['debit']?.toString() ?? '0') ?? 0;
      if (debit > 0) {
        final particular = t['parsed']?['name']?.toString();
        if (particular != null && particular != 'N/A') {
          data[particular] = (data[particular] ?? 0) + debit;
        }
      }
    }
    return data;
  }

  Widget _buildSpendingByCategoryCard() {
    return _buildGenericChartCard(
      title: "Spending by Category",
      chartKey: 'spendingByCategory',
      data: _calculateSpendingByCategory(),
    );
  }

  Widget _buildIncomeByCategoryCard() {
    return _buildGenericChartCard(
      title: "Income by Category",
      chartKey: 'incomeByCategory',
      data: _calculateIncomeByCategory(),
    );
  }

  Widget _buildSpendingBySubCategoryCard() {
    return _buildGenericChartCard(
      title: "Spending by Sub-Category",
      chartKey: 'spendingBySubCategory',
      data: _calculateSpendingBySubCategory(),
    );
  }

  Widget _buildSpendingByVpaCard() {
    return _buildGenericChartCard(
      title: "Spending by VPA",
      chartKey: 'spendingByVpa',
      data: _calculateSpendingByVpa(),
    );
  }

  Widget _buildSpendingByParticularsCard() {
    return _buildGenericChartCard(
      title: "Spending by Particulars",
      chartKey: 'spendingByParticulars',
      data: _calculateSpendingByParticulars(),
    );
  }

  Widget _buildGenericChartCard({
    required String title,
    required String chartKey,
    required Map<String, double> data,
  }) {
    final sortedData = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final displayData = sortedData.take(50).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SegmentedButton<ChartType>(
                  segments: const <ButtonSegment<ChartType>>[
                    ButtonSegment<ChartType>(
                      value: ChartType.pie,
                      icon: Icon(Icons.pie_chart_outline, size: 18),
                    ),
                    ButtonSegment<ChartType>(
                      value: ChartType.bar,
                      icon: Icon(Icons.bar_chart_outlined, size: 18),
                    ),
                    ButtonSegment<ChartType>(
                      value: ChartType.line,
                      icon: Icon(Icons.show_chart_outlined, size: 18),
                    ),
                  ],
                  selected: {_chartTypes[chartKey]!},
                  onSelectionChanged: (Set<ChartType> newSelection) {
                    setState(() {
                      _chartTypes[chartKey] = newSelection.first;
                    });
                  },
                  style: SegmentedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 250,
              child: data.isEmpty
                  ? const Center(child: Text("No data to display."))
                  : _buildChart(
                      chartType: _chartTypes[chartKey]!,
                      data: displayData,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value, {
    Color color = Colors.black,
  }) => Column(
    children: [
      Text(title, style: TextStyle(color: Colors.grey.shade600)),
      const SizedBox(height: 4),
      Text(
        value,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    ],
  );

  Widget _buildChart({
    required ChartType chartType,
    required List<MapEntry<String, double>> data,
  }) {
    switch (chartType) {
      case ChartType.pie:
        return _buildPieChart(data);
      case ChartType.bar:
        return _buildBarChart(data);
      case ChartType.line:
        return _buildLineChart(data);
    }
  }

  Widget _buildPieChart(List<MapEntry<String, double>> data) {
    return SfCircularChart(
      legend: const Legend(
        isVisible: true,
        overflowMode: LegendItemOverflowMode.wrap,
        position: LegendPosition.bottom,
      ),
      tooltipBehavior: TooltipBehavior(
        enable: true,
        format: 'point.x : ₹point.y',
      ),
      series: <CircularSeries>[
        DoughnutSeries<MapEntry<String, double>, String>(
          dataSource: data,
          xValueMapper: (entry, _) => entry.key,
          yValueMapper: (entry, _) => entry.value,
          dataLabelSettings: const DataLabelSettings(
            isVisible: true,
            textStyle: TextStyle(fontSize: 10, color: Colors.white),
            labelPosition: ChartDataLabelPosition.inside,
            connectorLineSettings: ConnectorLineSettings(
              type: ConnectorType.curve,
            ),
          ),
          pointColorMapper: (entry, index) =>
              _chartColors[index % _chartColors.length],
          innerRadius: '40%',
          explode: true,
          explodeIndex: 0,
          groupMode: CircularChartGroupMode.value,
          groupTo: 0,
        ),
      ],
    );
  }

  Widget _buildBarChart(List<MapEntry<String, double>> data) {
    return SfCartesianChart(
      primaryXAxis: CategoryAxis(
        labelIntersectAction: AxisLabelIntersectAction.rotate90,
        labelStyle: const TextStyle(fontSize: 10),
        interval: 1,
      ),
      zoomPanBehavior: ZoomPanBehavior(
        enablePinching: true,
        enablePanning: true,
        enableSelectionZooming: true,
        zoomMode: ZoomMode.x,
      ),
      primaryYAxis: NumericAxis(numberFormat: NumberFormat.decimalPattern()),
      tooltipBehavior: TooltipBehavior(enable: true),
      series: <CartesianSeries>[
        ColumnSeries<MapEntry<String, double>, String>(
          dataSource: data,
          xValueMapper: (entry, _) => entry.key,
          yValueMapper: (entry, _) => entry.value,
          pointColorMapper: (entry, index) =>
              _chartColors[index % _chartColors.length],
          dataLabelSettings: const DataLabelSettings(
            isVisible: true,
            angle: -90,
            textStyle: TextStyle(fontSize: 10),
          ),
        ),
      ],
    );
  }

  Widget _buildLineChart(List<MapEntry<String, double>> data) {
    return SfCartesianChart(
      primaryXAxis: CategoryAxis(
        labelIntersectAction: AxisLabelIntersectAction.rotate90,
        labelStyle: const TextStyle(fontSize: 10),
        interval: 1,
      ),
      zoomPanBehavior: ZoomPanBehavior(
        enablePinching: true,
        enablePanning: true,
        enableSelectionZooming: true,
        zoomMode: ZoomMode.x,
      ),
      primaryYAxis: NumericAxis(numberFormat: NumberFormat.decimalPattern()),
      tooltipBehavior: TooltipBehavior(enable: true),
      series: <CartesianSeries>[
        LineSeries<MapEntry<String, double>, String>(
          dataSource: data,
          xValueMapper: (entry, _) => entry.key,
          yValueMapper: (entry, _) => entry.value,
          markerSettings: const MarkerSettings(isVisible: true),
        ),
      ],
    );
  }

  Widget _buildTransactionGrid() {
    final visibleColumns = _allPossibleColumns
        .where((col) => _columnVisibility[col] ?? false)
        .toList();

    return Card(
      child: Column(
        children: [
          SizedBox(
            height:
                600, // Give the grid a fixed height to prevent layout issues
            child: SfDataGrid(
              source: _dataGridSource,
              allowSorting: true,
              allowMultiColumnSorting: true,
              allowTriStateSorting: true,
              allowColumnsResizing: true,
              columnResizeMode: ColumnResizeMode.onResizeEnd,
              columnWidthMode: ColumnWidthMode.none,
              columns: visibleColumns.map((colName) {
                double getColumnWidth() {
                  switch (colName) {
                    case 'Date':
                      return 100;
                    case 'Original Particulars':
                    case 'Original Description':
                    case 'Parsed Particulars':
                      return 250;
                    case 'Category':
                    case 'Sub-Category':
                      return 150;
                    case 'VPA':
                      return 180;
                    case 'Debit':
                    case 'Credit':
                    case 'Balance':
                      return 120;
                    default:
                      return 150; // A reasonable default
                  }
                }

                return GridColumn(
                  columnName: colName,
                  width: getColumnWidth(),
                  allowSorting: true,
                  label: Container(
                    padding: const EdgeInsets.all(8.0),
                    alignment: Alignment.center,
                    child: Text(colName, overflow: TextOverflow.ellipsis),
                  ),
                );
              }).toList(),
              onCellTap: (details) {
                if (details.rowColumnIndex.rowIndex > 0) {
                  final rowIndex = details.rowColumnIndex.rowIndex - 1;
                  if (rowIndex < _paginatedTransactions.length) {
                    final transactionData = _paginatedTransactions[rowIndex];
                    _showCategorizationDialog(transactionData);
                  }
                }
              },
            ),
          ),
          if (_filteredTransactions.isNotEmpty) _buildPaginationControls(),
        ],
      ),
    );
  }

  Widget _buildPaginationControls() {
    final totalRows = _filteredTransactions.length;
    final totalPages = (totalRows / _rowsPerPage).ceil();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Text("Rows:"),
              const SizedBox(width: 8),
              DropdownButton<int>(
                value: _rowsPerPage,
                items: _rowsPerPageOptions
                    .map(
                      (v) =>
                          DropdownMenuItem(value: v, child: Text(v.toString())),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) {
                    _rowsPerPage = v;
                    _currentPage = 0;
                    _paginateTransactions();
                  }
                },
              ),
            ],
          ),
          Row(
            children: [
              Text("Page ${_currentPage + 1} of $totalPages"),
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: _currentPage == 0
                    ? null
                    : () {
                        _currentPage--;
                        _paginateTransactions();
                      },
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: (_currentPage + 1) >= totalPages
                    ? null
                    : () {
                        _currentPage++;
                        _paginateTransactions();
                      },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showColumnVisibilityDialog() async {
    final tempVisibility = Map<String, bool>.from(_columnVisibility);
    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Manage Columns"),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView(
                  shrinkWrap: true,
                  children: _allPossibleColumns.map((col) {
                    return CheckboxListTile(
                      title: Text(col),
                      value: tempVisibility[col],
                      onChanged: (bool? value) {
                        setDialogState(() {
                          tempVisibility[col] = value ?? false;
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() => _columnVisibility = tempVisibility);
                    Navigator.of(context).pop();
                  },
                  child: const Text("Apply"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showCategorizationDialog(
    Map<String, dynamic> transaction,
  ) async {
    final mappingKey = widget.bankType == 'ipbp'
        ? (transaction['parsed']?['vpa'])
        : (transaction['parsed']?['name']);
    if (mappingKey == null || mappingKey == 'N/A') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("This transaction cannot be categorized."),
        ),
      );
      return;
    }

    String? selectedSubCategory = transaction['parsed']?['subCategory'] == 'N/A'
        ? null
        : transaction['parsed']?['subCategory'];
    final newCategoryController = TextEditingController();
    bool isAddingNew = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text("Categorize '$mappingKey'"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedSubCategory,
                    items: _subCategories
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (val) =>
                        setDialogState(() => selectedSubCategory = val),
                    decoration: const InputDecoration(
                      labelText: "Sub-Category",
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (isAddingNew)
                    TextField(
                      controller: newCategoryController,
                      decoration: const InputDecoration(
                        labelText: "New Sub-Category Name",
                      ),
                    )
                  else
                    TextButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text("Add New Sub-Category"),
                      onPressed: () => setDialogState(() => isAddingNew = true),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: () async {
                    String? finalSubCategory = selectedSubCategory;
                    if (isAddingNew && newCategoryController.text.isNotEmpty) {
                      finalSubCategory = newCategoryController.text.trim();
                      if (!_subCategories.contains(finalSubCategory)) {
                        await FirebaseFirestore.instance
                            .collection('artifacts')
                            .doc('default-app-id')
                            .collection('public')
                            .doc('data')
                            .collection('sub_categories')
                            .add({'name': finalSubCategory});
                        _subCategories.add(finalSubCategory);
                      }
                    }
                    if (finalSubCategory != null) {
                      await _saveMappingAndUpdateTransactions(
                        mappingKey,
                        finalSubCategory,
                      );
                      Navigator.of(context).pop();
                      _fetchTransactions(); // Refresh data
                    }
                  },
                  child: const Text("Save"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _saveMappingAndUpdateTransactions(
    String mappingKey,
    String subCategory,
  ) async {
    final userId = FirebaseAuth.instance.currentUser!.uid;
    final mappingCollectionName = widget.bankType == 'ipbp'
        ? 'ipbp_vpa_subcategory_mappings'
        : 'sbi_name_subcategory_mappings';
    final mappingField = widget.bankType == 'ipbp' ? 'vpa' : 'name';

    final mappingRef = FirebaseFirestore.instance
        .collection('artifacts')
        .doc('default-app-id')
        .collection('users')
        .doc(userId)
        .collection(mappingCollectionName);
    final query = await mappingRef
        .where(mappingField, isEqualTo: mappingKey)
        .limit(1)
        .get();
    if (query.docs.isNotEmpty) {
      await query.docs.first.reference.update({'subCategory': subCategory});
    } else {
      await mappingRef.add({
        mappingField: mappingKey,
        'subCategory': subCategory,
      });
    }

    // Background update
    final transactionCollectionName = '${widget.bankType}_transactions';
    final transactionRef = FirebaseFirestore.instance
        .collection('artifacts')
        .doc('default-app-id')
        .collection('users')
        .doc(userId)
        .collection(transactionCollectionName);
    final snapshot = await transactionRef
        .where('parsed.$mappingField', isEqualTo: mappingKey)
        .get();

    final batch = FirebaseFirestore.instance.batch();
    for (var doc in snapshot.docs) {
      final updatedParsed = Map<String, dynamic>.from(doc.data()['parsed']);
      updatedParsed['subCategory'] = subCategory;
      batch.update(doc.reference, {'parsed': updatedParsed});
    }
    await batch.commit();
  }
}
