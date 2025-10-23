import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:smart_roll_call_flutter/services/firestore_service.dart';
import 'package:intl/intl.dart';

class AttendanceOverviewScreen extends StatefulWidget {
  @override
  _AttendanceOverviewScreenState createState() =>
      _AttendanceOverviewScreenState();
}

class _AttendanceOverviewScreenState extends State<AttendanceOverviewScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  late TooltipBehavior _tooltipBehavior;

  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _trendsData;

  // Filter states
  String? _selectedBatchId;
  List<Map<String, String>> _batches = [];
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  String _selectedPeriod = 'Last 30 Days';

  @override
  void initState() {
    super.initState();
    _tooltipBehavior = TooltipBehavior(enable: true);
    _initializeData();
  }

  Future<void> _initializeData() async {
    try {
      // Get batches for filter
      final batches = await _firestoreService.getProfessorBatches();
      setState(() {
        _batches = batches;
      });

      // Load initial data
      await _loadAttendanceData();
    } catch (e) {
      setState(() {
        _error = 'Error loading data: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadAttendanceData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await _firestoreService.getAttendanceTrendsData(
        startDate: _startDate,
        endDate: _endDate,
        batchId: _selectedBatchId,
      );

      setState(() {
        _trendsData = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error loading attendance data: $e';
        _isLoading = false;
      });
    }
  }

  void _onPeriodChanged(String period) {
    setState(() {
      _selectedPeriod = period;
      final now = DateTime.now();

      switch (period) {
        case 'Last 7 Days':
          _startDate = now.subtract(const Duration(days: 7));
          _endDate = now;
          break;
        case 'Last 30 Days':
          _startDate = now.subtract(const Duration(days: 30));
          _endDate = now;
          break;
        case 'This Semester':
          // Approximate semester as 4 months
          _startDate = now.subtract(const Duration(days: 120));
          _endDate = now;
          break;
      }
    });
    _loadAttendanceData();
  }

  void _onBatchChanged(String? batchId) {
    setState(() {
      _selectedBatchId = batchId;
    });
    _loadAttendanceData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Attendance Trends'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAttendanceData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadAttendanceData,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _trendsData == null ||
                      _trendsData!['overallStats']['totalRecords'] == 0
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.inbox_outlined,
                              size: 48, color: Colors.grey),
                          const SizedBox(height: 16),
                          const Text(
                            'No attendance data available',
                            style: TextStyle(fontSize: 18, color: Colors.grey),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'for the selected period',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      child: Column(
                        children: [
                          // Filters
                          _buildFilters(),

                          // Overall Class Attendance
                          _buildOverallAttendanceCard(),

                          // Weekly Trends
                          if (_trendsData!['weeklyTrends'].isNotEmpty)
                            _buildWeeklyTrendsCard(),

                          // Batch-wise Statistics (if not filtered by batch)
                          if (_selectedBatchId == null &&
                              _trendsData!['batchStats'].isNotEmpty)
                            _buildBatchStatsCard(),

                          // Attendance Statistics
                          _buildStatisticsCard(),
                        ],
                      ),
                    ),
    );
  }

  Widget _buildFilters() {
    return Card(
      elevation: 2.0,
      margin: const EdgeInsets.all(16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Filters',
              style: TextStyle(
                fontSize: 18.0,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16.0),

            // Period Filter
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Time Period',
                border: OutlineInputBorder(),
              ),
              value: _selectedPeriod,
              items: ['Last 7 Days', 'Last 30 Days', 'This Semester']
                  .map((period) => DropdownMenuItem(
                        value: period,
                        child: Text(period),
                      ))
                  .toList(),
              onChanged: (value) {
                if (value != null) _onPeriodChanged(value);
              },
            ),
            const SizedBox(height: 12.0),

            // Batch Filter
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Batch (Optional)',
                border: OutlineInputBorder(),
              ),
              value: _selectedBatchId,
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('All Batches'),
                ),
                ..._batches.map((batch) => DropdownMenuItem(
                      value: batch['id'],
                      child: Text(batch['name']!),
                    )),
              ],
              onChanged: _onBatchChanged,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverallAttendanceCard() {
    final overallStats = _trendsData!['overallStats'];
    final chartData = [
      ChartData('Present', overallStats['presentPercentage'].toDouble()),
      ChartData('Absent', overallStats['absentPercentage'].toDouble()),
    ];

    return Card(
      elevation: 2.0,
      margin: const EdgeInsets.all(16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Overall Class Attendance',
              style: TextStyle(
                fontSize: 18.0,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8.0),
            Text(
              '${DateFormat('MMM dd, yyyy').format(_startDate)} - ${DateFormat('MMM dd, yyyy').format(_endDate)}',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            const SizedBox(height: 16.0),
            SfCircularChart(
              legend: Legend(isVisible: true),
              tooltipBehavior: _tooltipBehavior,
              series: <CircularSeries<ChartData, String>>[
                DoughnutSeries<ChartData, String>(
                  dataSource: chartData,
                  xValueMapper: (ChartData data, _) => data.x,
                  yValueMapper: (ChartData data, _) => data.y,
                  dataLabelSettings: const DataLabelSettings(isVisible: true),
                  enableTooltip: true,
                  pointColorMapper: (ChartData data, _) =>
                      data.x == 'Present' ? Colors.green : Colors.red,
                ),
              ],
            ),
            const SizedBox(height: 8.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  'Total Records',
                  overallStats['totalRecords'].toString(),
                  Icons.assignment,
                  Colors.blue,
                ),
                _buildStatItem(
                  'Present',
                  overallStats['presentCount'].toString(),
                  Icons.check_circle,
                  Colors.green,
                ),
                _buildStatItem(
                  'Absent',
                  overallStats['absentCount'].toString(),
                  Icons.cancel,
                  Colors.red,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyTrendsCard() {
    final weeklyTrends = _trendsData!['weeklyTrends'] as List;
    final chartData = weeklyTrends
        .map((trend) => ChartData(
              trend['week'] as String,
              (trend['percentage'] as num).toDouble(),
            ))
        .toList();

    return Card(
      elevation: 2.0,
      margin: const EdgeInsets.all(16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Weekly Attendance Trends',
              style: TextStyle(
                fontSize: 18.0,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16.0),
            SfCartesianChart(
              primaryXAxis: CategoryAxis(),
              primaryYAxis: NumericAxis(
                minimum: 0,
                maximum: 100,
                interval: 20,
                title: AxisTitle(text: 'Attendance %'),
              ),
              tooltipBehavior: _tooltipBehavior,
              series: <CartesianSeries<ChartData, String>>[
                LineSeries<ChartData, String>(
                  dataSource: chartData,
                  xValueMapper: (ChartData data, _) => data.x,
                  yValueMapper: (ChartData data, _) => data.y,
                  dataLabelSettings: const DataLabelSettings(isVisible: true),
                  enableTooltip: true,
                  markerSettings: const MarkerSettings(isVisible: true),
                  color: Colors.blue,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBatchStatsCard() {
    final batchStats = _trendsData!['batchStats'] as List;
    final chartData = batchStats
        .map((batch) => ChartData(
              batch['batchName'] as String,
              (batch['percentage'] as num).toDouble(),
            ))
        .toList();

    return Card(
      elevation: 2.0,
      margin: const EdgeInsets.all(16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Batch-wise Attendance',
              style: TextStyle(
                fontSize: 18.0,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16.0),
            SfCartesianChart(
              primaryXAxis: CategoryAxis(
                labelRotation: -45,
              ),
              primaryYAxis: NumericAxis(
                minimum: 0,
                maximum: 100,
                interval: 20,
                title: AxisTitle(text: 'Attendance %'),
              ),
              tooltipBehavior: _tooltipBehavior,
              series: <CartesianSeries<ChartData, String>>[
                ColumnSeries<ChartData, String>(
                  dataSource: chartData,
                  xValueMapper: (ChartData data, _) => data.x,
                  yValueMapper: (ChartData data, _) => data.y,
                  dataLabelSettings: const DataLabelSettings(isVisible: true),
                  enableTooltip: true,
                  color: Colors.teal,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatisticsCard() {
    final statistics = _trendsData!['statistics'];
    final highestWeek = statistics['highestWeek'];
    final lowestWeek = statistics['lowestWeek'];

    return Card(
      elevation: 2.0,
      margin: const EdgeInsets.all(16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Attendance Statistics',
              style: TextStyle(
                fontSize: 18.0,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16.0),
            _buildStatRow(
              'Average Attendance',
              '${statistics['averageAttendance']}%',
              Icons.analytics,
              Colors.blue,
            ),
            if (highestWeek != null) ...[
              const SizedBox(height: 8.0),
              _buildStatRow(
                'Highest Attendance',
                '${highestWeek['percentage']}% (${highestWeek['week']})',
                Icons.trending_up,
                Colors.green,
              ),
            ],
            if (lowestWeek != null) ...[
              const SizedBox(height: 8.0),
              _buildStatRow(
                'Lowest Attendance',
                '${lowestWeek['percentage']}% (${lowestWeek['week']})',
                Icons.trending_down,
                Colors.orange,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
      String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildStatRow(String label, String value, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 16),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

class ChartData {
  ChartData(this.x, this.y);
  final String x;
  final double y;
}
