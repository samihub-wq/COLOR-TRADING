import 'package:flutter/material.dart';
import 'dart:math';
import 'package:uuid/uuid.dart';

void main() {
  runApp(ColorTradingGameApp());
}

// Deposit request model
enum DepositStatus { pending, approved, rejected }

class DepositRequest {
  final String id;
  final String user;
  final int amount;
  final String provider; // "bKash" or "Nagad"
  final String trxId;
  DepositStatus status;
  final DateTime createdAt;

  DepositRequest({
    required this.id,
    required this.user,
    required this.amount,
    required this.provider,
    required this.trxId,
    this.status = DepositStatus.pending,
    required this.createdAt,
  });
}

// Withdraw request model
enum WithdrawStatus { pending, approved, rejected }

class WithdrawRequest {
  final String id;
  final String user;
  final int amount;
  final String accountInfo;
  WithdrawStatus status;
  final DateTime createdAt;
  WithdrawRequest({
    required this.id,
    required this.user,
    required this.amount,
    required this.accountInfo,
    this.status = WithdrawStatus.pending,
    required this.createdAt,
  });
}

// User model
class UserModel {
  String name;
  int balance;
  List<WithdrawRequest> withdraws;
  List<DepositRequest> deposits;
  UserModel({required this.name, this.balance = 0})
      : withdraws = [],
        deposits = [];
}

// Bet/history model
enum BetType { number, color, bigSmall }

class GameRoundResult {
  final String period;
  final int number;
  final String bigSmall;
  final String color;

  GameRoundResult({
    required this.period,
    required this.number,
    required this.bigSmall,
    required this.color,
  });
}

class BetTrack {
  Map<String, int> colorBetAmounts = {"Green": 0, "Red": 0, "Violet": 0};
  Map<String, int> bigSmallBetAmounts = {"Big": 0, "Small": 0};
  void reset() {
    colorBetAmounts = {"Green": 0, "Red": 0, "Violet": 0};
    bigSmallBetAmounts = {"Big": 0, "Small": 0};
  }
}

// For prediction access from AdminPanel
BetTrack? latestBetTrack;

class ColorTradingGameApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Color Trading Game',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.red),
      home: LoginScreen(),
    );
  }
}

/// Simple login for demo: "admin" is admin, others are users
class LoginScreen extends StatefulWidget {
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _nameCtrl = TextEditingController();
  String? _error;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.red.shade50,
      body: Center(
        child: Card(
          elevation: 4,
          margin: EdgeInsets.all(24),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Login",
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 24)),
                SizedBox(height: 20),
                TextField(
                  controller: _nameCtrl,
                  decoration: InputDecoration(
                      hintText: "Enter your name (admin = admin panel)",
                      errorText: _error,
                      border: OutlineInputBorder(),
                      isDense: true),
                ),
                SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    String name = _nameCtrl.text.trim();
                    if (name.isEmpty) {
                      setState(() => _error = "Enter your username");
                      return;
                    }
                    if (name.toLowerCase() == "admin") {
                      Navigator.pushReplacement(context,
                          MaterialPageRoute(builder: (_) => AdminPanel()));
                    } else {
                      Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                              builder: (_) => GameHome(currentUser: name)));
                    }
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      shape: StadiumBorder(),
                      minimumSize: Size(110, 42)),
                  child: Text("Login"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class GameHome extends StatefulWidget {
  final String currentUser;
  GameHome({required this.currentUser});
  @override
  State<GameHome> createState() => _GameHomeState();
}

class _GameHomeState extends State<GameHome> {
  static final Map<String, UserModel> users = {};
  static List<GameRoundResult> history = [];
  static final List<WithdrawRequest> allWithdraws = [];
  static final List<DepositRequest> allDeposits = [];

  // Timer options in seconds
  final List<int> timerOptions = [30, 60, 180, 300];
  int selectedTimer = 60;
  int timeLeft = 60;
  bool bettingOpen = true;
  bool showResult = false;
  bool isTimerRunning = false;

  // Game result
  String lastResultColor = "";
  int lastResultNumber = -1;
  String lastResultBigSmall = "";
  String currentPeriod = "";
  int roundId = 103990;

  // User selections
  String selectedColor = 'Green';
  int selectedNumber = -1;
  String selectedBigSmall = "";
  int betAmount = 100;

  // Bet tracking
  BetType? currentBetType;
  String? betColor;
  String? betBigSmall;
  int? betNumber;
  int placedBetAmount = 0;
  bool lastWin = false;
  int lastWinAmount = 0;

  UserModel get user => users.putIfAbsent(
      widget.currentUser, () => UserModel(name: widget.currentUser));
  int historyPage = 1;
  int historyPerPage = 10;
  bool showCongratulation = false;

  BetTrack betTrack = BetTrack();

  @override
  void initState() {
    super.initState();
    selectedTimer = timerOptions[1];
    timeLeft = selectedTimer;
    startTimer();
  }

  void startTimer() {
    String newPeriod =
        "202507151000${roundId + history.length + 1}".padLeft(15, "0");
    setState(() {
      timeLeft = selectedTimer;
      bettingOpen = true;
      showResult = false;
      isTimerRunning = true;
      lastResultColor = "";
      lastResultNumber = -1;
      lastResultBigSmall = "";
      selectedNumber = -1;
      selectedColor = 'Green';
      selectedBigSmall = "";
      currentBetType = null;
      betColor = null;
      betBigSmall = null;
      betNumber = null;
      placedBetAmount = 0;
      lastWin = false;
      lastWinAmount = 0;
      currentPeriod = newPeriod;
      showCongratulation = false;
      betTrack.reset();
      latestBetTrack = betTrack; // For admin prediction
    });

    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      if (timeLeft > 1) {
        setState(() {
          timeLeft--;
          bettingOpen = timeLeft > 5;
        });
        return true;
      } else {
        generateResult();
        setState(() {
          isTimerRunning = false;
          showResult = true;
        });
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) startTimer();
        });
        return false;
      }
    });
  }

  void generateResult() {
    final random = Random();
    // Anti-bias logic for color
    String maxColor = betTrack.colorBetAmounts.entries
        .reduce((a, b) => a.value >= b.value ? a : b)
        .key;
    int maxColorValue = betTrack.colorBetAmounts[maxColor]!;
    List<String> allowedColors = betTrack.colorBetAmounts.entries
        .where((e) => e.value < maxColorValue)
        .map((e) => e.key)
        .toList();
    if (allowedColors.isEmpty)
      allowedColors = betTrack.colorBetAmounts.keys.toList();
    String resultColor = allowedColors[random.nextInt(allowedColors.length)];
    // Big/Small anti-bias
    String maxBS = betTrack.bigSmallBetAmounts.entries
        .reduce((a, b) => a.value >= b.value ? a : b)
        .key;
    int maxBSValue = betTrack.bigSmallBetAmounts[maxBS]!;
    List<String> allowedBS = betTrack.bigSmallBetAmounts.entries
        .where((e) => e.value < maxBSValue)
        .map((e) => e.key)
        .toList();
    if (allowedBS.isEmpty)
      allowedBS = betTrack.bigSmallBetAmounts.keys.toList();
    String resultBS = allowedBS[random.nextInt(allowedBS.length)];
    int resultNumber = random.nextInt(10);

    lastResultColor = resultColor;
    lastResultBigSmall = resultBS;
    lastResultNumber = resultNumber;

    setState(() {
      history.insert(
        0,
        GameRoundResult(
          period: currentPeriod,
          number: lastResultNumber,
          bigSmall: lastResultBigSmall,
          color: lastResultColor,
        ),
      );
    });

    bool win = false;
    if (currentBetType == BetType.number && betNumber == lastResultNumber)
      win = true;
    if (currentBetType == BetType.color && betColor == lastResultColor)
      win = true;
    if (currentBetType == BetType.bigSmall && betBigSmall == lastResultBigSmall)
      win = true;

    if (win && placedBetAmount > 0) {
      int bonus = placedBetAmount * 2;
      setState(() {
        user.balance += bonus;
        lastWin = true;
        lastWinAmount = bonus;
        showCongratulation = true;
      });
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => showCongratulation = false);
      });
    } else {
      setState(() {
        lastWin = false;
        lastWinAmount = 0;
        showCongratulation = false;
      });
    }
    setState(() {
      placedBetAmount = 0;
      currentBetType = null;
      betColor = null;
      betBigSmall = null;
      betNumber = null;
    });
  }

  void placeNumberBet() {
    if (!bettingOpen || selectedNumber == -1 || betAmount > user.balance)
      return;
    setState(() {
      currentBetType = BetType.number;
      betNumber = selectedNumber;
      betColor = null;
      betBigSmall = null;
      placedBetAmount = betAmount;
      user.balance -= betAmount;
    });
  }

  void placeColorBet() {
    if (!bettingOpen || selectedColor.isEmpty || betAmount > user.balance)
      return;
    setState(() {
      currentBetType = BetType.color;
      betColor = selectedColor;
      betNumber = null;
      betBigSmall = null;
      placedBetAmount = betAmount;
      user.balance -= betAmount;
      betTrack.colorBetAmounts[selectedColor] =
          betTrack.colorBetAmounts[selectedColor]! + betAmount;
    });
  }

  void placeBigSmallBet(String type) {
    if (!bettingOpen || betAmount > user.balance) return;
    setState(() {
      currentBetType = BetType.bigSmall;
      betBigSmall = type;
      betColor = null;
      betNumber = null;
      placedBetAmount = betAmount;
      user.balance -= betAmount;
      selectedBigSmall = type;
      betTrack.bigSmallBetAmounts[type] =
          betTrack.bigSmallBetAmounts[type]! + betAmount;
    });
  }

  // Deposit Panel Logic
  void showDepositDialog() {
    int amount = 0;
    String provider = "bKash";
    final TextEditingController trxCtrl = TextEditingController();
    String? error;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: Text("Deposit"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<String>(
                      value: "bKash",
                      groupValue: provider,
                      onChanged: (v) => setDialog(() => provider = v!),
                      title: Text("bKash"),
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<String>(
                      value: "Nagad",
                      groupValue: provider,
                      onChanged: (v) => setDialog(() => provider = v!),
                      title: Text("Nagad"),
                    ),
                  ),
                ],
              ),
              TextField(
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: "Amount (min 100)"),
                onChanged: (val) {
                  amount = int.tryParse(val) ?? 0;
                },
              ),
              TextField(
                controller: trxCtrl,
                decoration: InputDecoration(labelText: "Transaction ID"),
              ),
              SizedBox(height: 7),
              if (provider == "bKash")
                Text(
                  "Send Money to bKash: +8801767668270",
                  style: TextStyle(fontSize: 13, color: Colors.deepPurple),
                ),
              if (provider == "Nagad")
                Text(
                  "Send Money to Nagad: +8801746259678",
                  style: TextStyle(fontSize: 13, color: Colors.deepOrange),
                ),
              SizedBox(height: 7),
              Text(
                "After sending, input TrxID and submit.",
                style: TextStyle(fontSize: 12, color: Colors.black87),
              ),
              if (error != null)
                Text(error!, style: TextStyle(color: Colors.red, fontSize: 13)),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                },
                child: Text("Cancel")),
            ElevatedButton(
                onPressed: () {
                  if (amount < 100) {
                    setDialog(() => error = "Minimum deposit is 100৳");
                    return;
                  }
                  if (trxCtrl.text.trim().isEmpty) {
                    setDialog(() => error = "Transaction ID required");
                    return;
                  }
                  final req = DepositRequest(
                    id: Uuid().v4(),
                    user: widget.currentUser,
                    amount: amount,
                    provider: provider,
                    trxId: trxCtrl.text.trim(),
                    status: DepositStatus.pending,
                    createdAt: DateTime.now(),
                  );
                  setState(() {
                    user.deposits.add(req);
                    allDeposits.add(req);
                  });
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text("Deposit request submitted!"),
                    backgroundColor: Colors.green,
                  ));
                },
                child: Text("Submit"))
          ],
        ),
      ),
    );
  }

  // Withdraw Panel Logic
  void showWithdrawDialog() {
    int amount = 0;
    final TextEditingController accCtrl = TextEditingController();
    String? error;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: Text("Withdraw"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: "Amount"),
                onChanged: (val) {
                  amount = int.tryParse(val) ?? 0;
                },
              ),
              TextField(
                controller: accCtrl,
                decoration: InputDecoration(labelText: "Bkash/Nagad/Bank Info"),
              ),
              if (error != null)
                Text(error!, style: TextStyle(color: Colors.red, fontSize: 13)),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                },
                child: Text("Cancel")),
            ElevatedButton(
                onPressed: () {
                  if (amount <= 0) {
                    setDialog(() => error = "Amount required");
                    return;
                  }
                  if (amount > user.balance) {
                    setDialog(() => error = "Not enough balance");
                    return;
                  }
                  if (accCtrl.text.trim().isEmpty) {
                    setDialog(() => error = "Account info required");
                    return;
                  }
                  final req = WithdrawRequest(
                    id: Uuid().v4(),
                    user: widget.currentUser,
                    amount: amount,
                    accountInfo: accCtrl.text.trim(),
                    status: WithdrawStatus.pending,
                    createdAt: DateTime.now(),
                  );
                  setState(() {
                    user.balance -= amount;
                    user.withdraws.add(req);
                    allWithdraws.add(req);
                  });
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text("Withdraw request submitted"),
                    backgroundColor: Colors.orange,
                  ));
                },
                child: Text("Request"))
          ],
        ),
      ),
    );
  }

  Widget buildDepositPanel() {
    return Card(
      margin: EdgeInsets.only(top: 18, bottom: 10),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text("Deposit Panel",
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Spacer(),
                ElevatedButton(
                  onPressed: showDepositDialog,
                  child: Text("Deposit"),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[700],
                      minimumSize: Size(0, 32)),
                ),
              ],
            ),
            Divider(),
            if (user.deposits.isEmpty)
              Padding(
                padding: const EdgeInsets.all(6.0),
                child: Text("No Deposit Requests yet.",
                    style: TextStyle(color: Colors.grey[700])),
              )
            else
              Column(
                children: user.deposits
                    .map((d) => ListTile(
                          title: Text("৳${d.amount} | ${d.provider}"),
                          subtitle: Text(
                              "TrxID: ${d.trxId}\n${d.createdAt.toLocal().toString().substring(0, 19)}"),
                          trailing: Text(
                            d.status == DepositStatus.pending
                                ? "Pending"
                                : d.status == DepositStatus.approved
                                    ? "Approved"
                                    : "Rejected",
                            style: TextStyle(
                                color: d.status == DepositStatus.pending
                                    ? Colors.orange
                                    : d.status == DepositStatus.approved
                                        ? Colors.green
                                        : Colors.red),
                          ),
                          dense: true,
                          isThreeLine: true,
                        ))
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget buildWithdrawPanel() {
    return Card(
      margin: EdgeInsets.only(bottom: 10),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text("Withdraw Panel",
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Spacer(),
                ElevatedButton(
                  onPressed: showWithdrawDialog,
                  child: Text("Withdraw"),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[400],
                      minimumSize: Size(0, 32)),
                ),
              ],
            ),
            Divider(),
            if (user.withdraws.isEmpty)
              Padding(
                padding: const EdgeInsets.all(6.0),
                child: Text("No Withdraw Requests yet.",
                    style: TextStyle(color: Colors.grey[700])),
              )
            else
              Column(
                children: user.withdraws
                    .map((w) => ListTile(
                          title: Text("৳${w.amount}"),
                          subtitle: Text(
                              "${w.accountInfo}\n${w.createdAt.toLocal().toString().substring(0, 19)}"),
                          trailing: Text(
                            w.status == WithdrawStatus.pending
                                ? "Pending"
                                : w.status == WithdrawStatus.approved
                                    ? "Approved"
                                    : "Rejected",
                            style: TextStyle(
                                color: w.status == WithdrawStatus.pending
                                    ? Colors.orange
                                    : w.status == WithdrawStatus.approved
                                        ? Colors.green
                                        : Colors.red),
                          ),
                          dense: true,
                          isThreeLine: true,
                        ))
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget buildTimerTabs() {
    /* same as previous code */
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: timerOptions.map((sec) {
        String label;
        if (sec == 30)
          label = "30 SEC";
        else if (sec == 60)
          label = "1 MIN";
        else if (sec == 180)
          label = "3 MIN";
        else
          label = "5 MIN";
        bool selected = selectedTimer == sec;
        return Expanded(
          child: GestureDetector(
            onTap: () {
              if (isTimerRunning) return;
              setState(() {
                selectedTimer = sec;
                timeLeft = selectedTimer;
                bettingOpen = true;
                showResult = false;
                isTimerRunning = false;
              });
              startTimer();
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: selected ? Colors.redAccent : Colors.grey[200],
                borderRadius: BorderRadius.circular(14),
                border:
                    selected ? Border.all(color: Colors.red, width: 2) : null,
              ),
              child: Center(
                child: Text(label,
                    style: TextStyle(
                      color: selected ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    )),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget buildTimerAndBalance() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Card(
          color: Colors.red[100],
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            child: Row(
              children: [
                Icon(Icons.account_balance_wallet, color: Colors.red[400]),
                SizedBox(width: 8),
                Text(
                  "${user.balance} ৳",
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.red[400]),
                ),
                SizedBox(width: 8),
              ],
            ),
          ),
        ),
        Card(
          color: Colors.red[50],
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.timer, color: Colors.red[400]),
                SizedBox(width: 8),
                Text(
                  timeLeft < 10 ? "00:0$timeLeft" : "00:$timeLeft",
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                      color: Colors.red[400]),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget buildColorButtons() {
    /* previous code, unchanged */
    List<String> colors = ['Green', 'Violet', 'Red'];
    List<Color> btnColors = [Colors.green, Colors.purple, Colors.redAccent];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(3, (i) {
        bool selected = selectedColor == colors[i];
        return Expanded(
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: 5, vertical: 8),
            child: ElevatedButton(
              onPressed: bettingOpen
                  ? () {
                      setState(() {
                        selectedColor = colors[i];
                        selectedBigSmall = "";
                        selectedNumber = -1;
                      });
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    selected ? btnColors[i].withOpacity(0.8) : btnColors[i],
                padding: EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: selected ? 8 : 3,
                shadowColor: btnColors[i].withOpacity(0.4),
              ),
              child: Text(
                colors[i],
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.1,
                    fontSize: 17),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget buildNumberGrid() {
    /* previous code, unchanged */
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 10),
      child: GridView.builder(
        itemCount: 10,
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5, mainAxisSpacing: 14, crossAxisSpacing: 14),
        itemBuilder: (context, i) {
          bool selected = selectedNumber == i;
          return GestureDetector(
            onTap: bettingOpen
                ? () {
                    setState(() {
                      selectedNumber = i;
                      selectedColor = '';
                      selectedBigSmall = "";
                    });
                  }
                : null,
            child: AnimatedContainer(
              duration: Duration(milliseconds: 200),
              decoration: BoxDecoration(
                gradient: selected
                    ? LinearGradient(
                        colors: [Colors.orangeAccent, Colors.pinkAccent],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : LinearGradient(
                        colors: [
                          i % 2 == 0 ? Colors.green[100]! : Colors.purple[50]!,
                          Colors.white
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: selected
                        ? Colors.orangeAccent.withOpacity(0.5)
                        : Colors.grey.withOpacity(0.2),
                    blurRadius: selected ? 12 : 4,
                    offset: Offset(0, 3),
                  )
                ],
                border: Border.all(
                    color: selected ? Colors.deepOrange : Colors.transparent,
                    width: 2.5),
              ),
              child: Center(
                child: Text(
                  "$i",
                  style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: selected ? Colors.white : Colors.black87,
                      shadows: selected
                          ? [
                              Shadow(
                                  color: Colors.orangeAccent,
                                  blurRadius: 10,
                                  offset: Offset(0, 2))
                            ]
                          : []),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget buildBetControls() {
    /* previous code, unchanged */
    return Column(
      children: [
        Row(
          children: [
            Text(
              "Bet: ",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            SizedBox(
              width: 80,
              child: TextField(
                enabled: bettingOpen,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    isDense: true),
                controller: TextEditingController(text: betAmount.toString()),
                onChanged: (v) {
                  int value = int.tryParse(v) ?? 100;
                  setState(() {
                    betAmount = value;
                  });
                },
              ),
            ),
            Text(" ৳"),
          ],
        ),
        SizedBox(height: 15),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: bettingOpen &&
                        selectedNumber != -1 &&
                        betAmount > 0 &&
                        betAmount <= user.balance
                    ? placeNumberBet
                    : null,
                child: Text("Bet Number"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: bettingOpen &&
                          selectedNumber != -1 &&
                          betAmount > 0 &&
                          betAmount <= user.balance
                      ? Colors.redAccent
                      : Colors.grey[400],
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: ElevatedButton(
                onPressed: bettingOpen &&
                        selectedColor.isNotEmpty &&
                        betAmount > 0 &&
                        betAmount <= user.balance
                    ? placeColorBet
                    : null,
                child: Text("Bet Color"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: bettingOpen &&
                          selectedColor.isNotEmpty &&
                          betAmount > 0 &&
                          betAmount <= user.balance
                      ? Colors.green
                      : Colors.grey[400],
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget buildBigSmallButtons() {
    /* previous code, unchanged */
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: bettingOpen && betAmount > 0 && betAmount <= user.balance
                ? () => placeBigSmallBet('Big')
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  bettingOpen && betAmount > 0 && betAmount <= user.balance
                      ? Colors.green
                      : Colors.grey[400],
              padding: EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
            ),
            child: Text("Bet Big",
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                    color: Colors.white)),
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: bettingOpen && betAmount > 0 && betAmount <= user.balance
                ? () => placeBigSmallBet('Small')
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  bettingOpen && betAmount > 0 && betAmount <= user.balance
                      ? Colors.blue[300]
                      : Colors.grey[400],
              padding: EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
            ),
            child: Text("Bet Small",
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                    color: Colors.white)),
          ),
        ),
      ],
    );
  }

  // Rest of result, congrats, history, etc. (same as previous code)
  Widget buildCongratulationCard() {
    /* previous code, unchanged */
    if (!showCongratulation) return SizedBox.shrink();
    Color mainColor = lastResultColor == "Red"
        ? Colors.redAccent
        : lastResultColor == "Green"
            ? Colors.green
            : Colors.purple;
    return Center(
      child: Container(
        width: 330,
        constraints: BoxConstraints(maxWidth: 380),
        margin: EdgeInsets.only(top: 60, bottom: 30),
        padding: EdgeInsets.symmetric(vertical: 26, horizontal: 22),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [mainColor.withOpacity(0.95), Colors.orangeAccent.shade100],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
                color: Colors.orangeAccent.withOpacity(0.28),
                blurRadius: 24,
                offset: Offset(0, 10))
          ],
          border: Border.all(color: Colors.orange.shade300, width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(color: Colors.orangeAccent, width: 3),
                boxShadow: [
                  BoxShadow(
                      color: Colors.orange.withOpacity(0.12),
                      blurRadius: 10,
                      offset: Offset(0, 2))
                ],
              ),
              child: Icon(Icons.rocket, color: Colors.amber, size: 48),
            ),
            SizedBox(height: 6),
            Text(
              "Congratulations",
              style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                        color: Colors.black.withOpacity(0.18),
                        blurRadius: 6,
                        offset: Offset(0, 2))
                  ]),
            ),
            SizedBox(height: 10),
            Text(
              "Lottery results",
              style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.bold,
                  fontSize: 15),
            ),
            SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                buildResultLabel(lastResultColor, mainColor),
                SizedBox(width: 8),
                buildResultLabel(lastResultNumber.toString(), mainColor),
                SizedBox(width: 8),
                buildResultLabel(lastResultBigSmall, mainColor),
              ],
            ),
            SizedBox(height: 18),
            Container(
              padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.orangeAccent.withOpacity(0.19),
                        blurRadius: 4,
                        offset: Offset(0, 2))
                  ]),
              child: Column(
                children: [
                  Text(
                    "Bonus",
                    style: TextStyle(
                        color: mainColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16),
                  ),
                  SizedBox(height: 4),
                  Text(
                    "৳${lastWinAmount.toStringAsFixed(2)}",
                    style: TextStyle(
                        fontSize: 30,
                        color: Colors.deepOrange,
                        fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 6),
                  Text(
                    "Period: ${currentPeriod.length > 5 ? (selectedTimer == 30 ? "WinGo 30sec" : selectedTimer == 60 ? "WinGo 1min" : selectedTimer == 180 ? "WinGo 3min" : "WinGo 5min") : ""}",
                    style: TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                  Text(
                    currentPeriod,
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
            ),
            SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.timer, color: Colors.white70, size: 18),
                SizedBox(width: 6),
                Text(
                  "3 seconds auto close",
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
            SizedBox(height: 8),
            GestureDetector(
              onTap: () {
                setState(() => showCongratulation = false);
              },
              child: Container(
                margin: EdgeInsets.only(top: 4),
                padding: EdgeInsets.all(5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.8),
                ),
                child: Icon(Icons.close, color: mainColor, size: 32),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildResultLabel(String txt, Color color) {
    /* previous code */
    return Container(
      padding: EdgeInsets.symmetric(vertical: 2, horizontal: 13),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: color.withOpacity(0.8),
      ),
      child: Text(
        txt,
        style: TextStyle(
            color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
      ),
    );
  }

  Widget buildResultBox() {
    /* previous code */
    if (!showResult) return SizedBox.shrink();
    if (lastWin) return SizedBox.shrink();
    return Container(
      margin: EdgeInsets.symmetric(vertical: 10),
      padding: EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
            colors: [Colors.yellow.shade100, Colors.red.shade100],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        boxShadow: [
          BoxShadow(
              color: Colors.red.shade100.withOpacity(0.3),
              blurRadius: 12,
              offset: Offset(0, 7))
        ],
        border: Border.all(color: Colors.red, width: 2),
      ),
      child: Column(
        children: [
          Text(
            "Result",
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: Colors.deepOrange),
          ),
          SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                backgroundColor: lastResultColor == "Green"
                    ? Colors.green
                    : lastResultColor == "Red"
                        ? Colors.red
                        : Colors.purple,
                radius: 24,
                child: Text(
                  lastResultNumber >= 0 ? "$lastResultNumber" : "-",
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 26),
                ),
              ),
              SizedBox(width: 18),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Color: $lastResultColor",
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: lastResultColor == "Green"
                            ? Colors.green
                            : lastResultColor == "Red"
                                ? Colors.red
                                : Colors.purple),
                  ),
                  Text(
                    "Type: $lastResultBigSmall",
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: lastResultBigSmall == "Big"
                            ? Colors.deepOrange
                            : Colors.blue),
                  ),
                ],
              )
            ],
          ),
          SizedBox(height: 10),
          if (placedBetAmount == 0)
            Text(
              lastWin ? "" : "You Lose!",
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: lastWin ? Colors.green : Colors.red),
            ),
        ],
      ),
    );
  }

  Widget buildHistoryTable() {
    /* previous code */
    int totalPages =
        (history.length / historyPerPage).ceil().clamp(1, 9999).toInt();
    int page = historyPage.clamp(1, totalPages);
    int start = (page - 1) * historyPerPage;
    int end = (start + historyPerPage).clamp(0, history.length);

    List<GameRoundResult> pageHistory = history.sublist(start, end);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          elevation: 2,
          margin: EdgeInsets.only(top: 18),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 12, horizontal: 10),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                        flex: 3,
                        child: Text("Period",
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.red))),
                    Expanded(
                        flex: 1,
                        child: Center(
                            child: Text("Number",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red)))),
                    Expanded(
                        flex: 2,
                        child: Center(
                            child: Text("Big Small",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red)))),
                    Expanded(
                        flex: 1,
                        child: Center(
                            child: Text("Color",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red)))),
                  ],
                ),
                Divider(color: Colors.red[200], thickness: 1, height: 16),
                ...pageHistory.map((r) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 1.5),
                      child: Row(
                        children: [
                          Expanded(
                              flex: 3,
                              child: Text(r.period,
                                  style: TextStyle(fontSize: 12))),
                          Expanded(
                              flex: 1,
                              child: Center(
                                  child: Text(
                                r.number.toString(),
                                style: TextStyle(
                                    fontSize: 22,
                                    color: r.color == "Green"
                                        ? Colors.green
                                        : r.color == "Red"
                                            ? Colors.red
                                            : Colors.purple,
                                    fontWeight: FontWeight.bold),
                              ))),
                          Expanded(
                              flex: 2,
                              child: Center(
                                  child: Text(
                                r.bigSmall,
                                style: TextStyle(
                                    color: r.bigSmall == "Big"
                                        ? Colors.deepOrange
                                        : Colors.blue,
                                    fontWeight: FontWeight.bold),
                              ))),
                          Expanded(
                              flex: 1,
                              child: Center(
                                  child: Icon(
                                Icons.circle,
                                color: r.color == "Green"
                                    ? Colors.green
                                    : r.color == "Red"
                                        ? Colors.red
                                        : Colors.purple,
                                size: 16,
                              ))),
                        ],
                      ),
                    )),
                SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                        onPressed: page > 1
                            ? () {
                                setState(() {
                                  historyPage--;
                                });
                              }
                            : null,
                        icon: Icon(Icons.chevron_left)),
                    Text(
                      "$page/$totalPages",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                        onPressed: page < totalPages
                            ? () {
                                setState(() {
                                  historyPage++;
                                });
                              }
                            : null,
                        icon: Icon(Icons.chevron_right)),
                  ],
                )
              ],
            ),
          ),
        )
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.red.shade50.withOpacity(0.95),
      appBar: AppBar(
        title: Text("Color Trading Game",
            style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        backgroundColor: Colors.redAccent,
        elevation: 1,
        centerTitle: true,
        actions: [
          IconButton(
              onPressed: () {
                Navigator.pushReplacement(
                    context, MaterialPageRoute(builder: (_) => LoginScreen()));
              },
              icon: Icon(Icons.logout))
        ],
      ),
      body: Stack(
        children: [
          ListView(
            padding: EdgeInsets.symmetric(horizontal: 16),
            children: [
              SizedBox(height: 12),
              buildTimerTabs(),
              buildTimerAndBalance(),
              buildDepositPanel(),
              buildWithdrawPanel(),
              SizedBox(height: 12),
              buildColorButtons(),
              buildNumberGrid(),
              buildBetControls(),
              SizedBox(height: 10),
              buildBigSmallButtons(),
              buildResultBox(),
              buildHistoryTable(),
              SizedBox(height: 15),
              if (!bettingOpen && !showResult)
                Center(
                    child: Text(
                  "Betting Closed! Please wait for next round...",
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red[400],
                      fontSize: 16),
                )),
            ],
          ),
          if (showCongratulation) ...[
            Container(
              color: Colors.black.withOpacity(0.25),
              width: double.infinity,
              height: double.infinity,
            ),
            buildCongratulationCard(),
          ]
        ],
      ),
    );
  }
}

// Admin Panel
class AdminPanel extends StatefulWidget {
  @override
  State<AdminPanel> createState() => _AdminPanelState();
}

class _AdminPanelState extends State<AdminPanel> {
  List<WithdrawRequest> get withdraws => _GameHomeState.allWithdraws;
  List<DepositRequest> get deposits => _GameHomeState.allDeposits;
  Map<String, UserModel> get users => _GameHomeState.users;
  int withdrawFilter = 0;
  int depositFilter = 0;

  @override
  Widget build(BuildContext context) {
    final filteredWithdraws = withdraws
        .where((w) =>
            withdrawFilter == 0 ||
            (withdrawFilter == 1 && w.status == WithdrawStatus.pending) ||
            (withdrawFilter == 2 && w.status == WithdrawStatus.approved) ||
            (withdrawFilter == 3 && w.status == WithdrawStatus.rejected))
        .toList();
    final filteredDeposits = deposits
        .where((d) =>
            depositFilter == 0 ||
            (depositFilter == 1 && d.status == DepositStatus.pending) ||
            (depositFilter == 2 && d.status == DepositStatus.approved) ||
            (depositFilter == 3 && d.status == DepositStatus.rejected))
        .toList();

    // Prediction Logic (same as game anti-bias)
    BetTrack? betTrack = latestBetTrack;
    String nextColor = "-";
    String nextBigSmall = "-";
    String nextNumber = "0-9 random";
    if (betTrack != null) {
      String maxColor = betTrack.colorBetAmounts.entries
          .reduce((a, b) => a.value >= b.value ? a : b)
          .key;
      int maxColorValue = betTrack.colorBetAmounts[maxColor]!;
      List<String> allowedColors = betTrack.colorBetAmounts.entries
          .where((e) => e.value < maxColorValue)
          .map((e) => e.key)
          .toList();
      if (allowedColors.isEmpty)
        allowedColors = betTrack.colorBetAmounts.keys.toList();
      nextColor = allowedColors.join(" অথবা ");

      String maxBS = betTrack.bigSmallBetAmounts.entries
          .reduce((a, b) => a.value >= b.value ? a : b)
          .key;
      int maxBSValue = betTrack.bigSmallBetAmounts[maxBS]!;
      List<String> allowedBS = betTrack.bigSmallBetAmounts.entries
          .where((e) => e.value < maxBSValue)
          .map((e) => e.key)
          .toList();
      if (allowedBS.isEmpty)
        allowedBS = betTrack.bigSmallBetAmounts.keys.toList();
      nextBigSmall = allowedBS.join(" অথবা ");
    }

    return Scaffold(
      backgroundColor: Colors.red.shade50,
      appBar: AppBar(
        title: Text("Admin Panel"),
        backgroundColor: Colors.redAccent,
        actions: [
          IconButton(
              onPressed: () {
                Navigator.pushReplacement(
                    context, MaterialPageRoute(builder: (_) => LoginScreen()));
              },
              icon: Icon(Icons.logout))
        ],
      ),
      body: ListView(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        children: [
          // Next Prediction
          Card(
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Next Outcome Prediction",
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Divider(),
                  Text("Next Color: $nextColor",
                      style: TextStyle(
                          color: Colors.green[800],
                          fontWeight: FontWeight.bold)),
                  SizedBox(height: 6),
                  Text("Next Big/Small: $nextBigSmall",
                      style: TextStyle(
                          color: Colors.red[800], fontWeight: FontWeight.bold)),
                  SizedBox(height: 6),
                  Text("Next Number: $nextNumber",
                      style: TextStyle(
                          color: Colors.purple[800],
                          fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text(
                      "Prediction is based on current round bet amounts (anti-bias logic)",
                      style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                ],
              ),
            ),
          ),
          // Deposit Requests
          Card(
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Deposit Requests",
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  SizedBox(height: 9),
                  Row(
                    children: [
                      FilterChip(
                        label: Text("All"),
                        selected: depositFilter == 0,
                        onSelected: (_) => setState(() => depositFilter = 0),
                      ),
                      SizedBox(width: 8),
                      FilterChip(
                        label: Text("Pending"),
                        selected: depositFilter == 1,
                        onSelected: (_) => setState(() => depositFilter = 1),
                        backgroundColor: Colors.orange[100],
                        selectedColor: Colors.orange,
                      ),
                      SizedBox(width: 8),
                      FilterChip(
                        label: Text("Approved"),
                        selected: depositFilter == 2,
                        onSelected: (_) => setState(() => depositFilter = 2),
                        backgroundColor: Colors.green[100],
                        selectedColor: Colors.green,
                      ),
                      SizedBox(width: 8),
                      FilterChip(
                        label: Text("Rejected"),
                        selected: depositFilter == 3,
                        onSelected: (_) => setState(() => depositFilter = 3),
                        backgroundColor: Colors.red[100],
                        selectedColor: Colors.red,
                      ),
                    ],
                  ),
                  Divider(),
                  if (filteredDeposits.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text("No deposit requests found."),
                    )
                  else
                    ...filteredDeposits.map((d) {
                      return Card(
                        margin: EdgeInsets.symmetric(vertical: 7),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        child: ListTile(
                          leading: CircleAvatar(
                              backgroundColor: Colors.green,
                              child: Text(d.user[0].toUpperCase())),
                          title: Text(
                              "${d.user} | ৳${d.amount} | ${d.provider} | TrxID: ${d.trxId}",
                              style: TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(
                              "${d.createdAt.toLocal().toString().substring(0, 19)}"),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (d.status == DepositStatus.pending)
                                ElevatedButton(
                                  onPressed: () {
                                    setState(() {
                                      d.status = DepositStatus.approved;
                                      users[d.user]?.balance += d.amount;
                                    });
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                            content: Text(
                                                "Approved & Added ৳${d.amount} to ${d.user}"),
                                            backgroundColor: Colors.green));
                                  },
                                  child: Text("Approve"),
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green),
                                ),
                              if (d.status == DepositStatus.pending)
                                SizedBox(width: 7),
                              if (d.status == DepositStatus.pending)
                                ElevatedButton(
                                  onPressed: () {
                                    setState(() {
                                      d.status = DepositStatus.rejected;
                                    });
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                            content: Text(
                                                "Rejected deposit of ৳${d.amount} for ${d.user}"),
                                            backgroundColor: Colors.red));
                                  },
                                  child: Text("Reject"),
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red),
                                ),
                              if (d.status != DepositStatus.pending)
                                Text(
                                  d.status == DepositStatus.approved
                                      ? "Approved"
                                      : "Rejected",
                                  style: TextStyle(
                                      color: d.status == DepositStatus.approved
                                          ? Colors.green
                                          : Colors.red,
                                      fontWeight: FontWeight.bold),
                                ),
                            ],
                          ),
                        ),
                      );
                    })
                ],
              ),
            ),
          ),
          // Withdraw Requests
          Card(
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Withdraw Requests",
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  SizedBox(height: 9),
                  Row(
                    children: [
                      FilterChip(
                        label: Text("All"),
                        selected: withdrawFilter == 0,
                        onSelected: (_) => setState(() => withdrawFilter = 0),
                      ),
                      SizedBox(width: 8),
                      FilterChip(
                        label: Text("Pending"),
                        selected: withdrawFilter == 1,
                        onSelected: (_) => setState(() => withdrawFilter = 1),
                        backgroundColor: Colors.orange[100],
                        selectedColor: Colors.orange,
                      ),
                      SizedBox(width: 8),
                      FilterChip(
                        label: Text("Approved"),
                        selected: withdrawFilter == 2,
                        onSelected: (_) => setState(() => withdrawFilter = 2),
                        backgroundColor: Colors.green[100],
                        selectedColor: Colors.green,
                      ),
                      SizedBox(width: 8),
                      FilterChip(
                        label: Text("Rejected"),
                        selected: withdrawFilter == 3,
                        onSelected: (_) => setState(() => withdrawFilter = 3),
                        backgroundColor: Colors.red[100],
                        selectedColor: Colors.red,
                      ),
                    ],
                  ),
                  Divider(),
                  if (filteredWithdraws.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text("No withdraws found."),
                    )
                  else
                    ...filteredWithdraws.map((w) {
                      return Card(
                        margin: EdgeInsets.symmetric(vertical: 7),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        child: ListTile(
                          leading: CircleAvatar(
                              backgroundColor: Colors.red,
                              child: Text(w.user[0].toUpperCase())),
                          title: Text(
                              "${w.user} | ৳${w.amount} | ${w.accountInfo}",
                              style: TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(
                              "${w.createdAt.toLocal().toString().substring(0, 19)}"),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (w.status == WithdrawStatus.pending)
                                ElevatedButton(
                                  onPressed: () {
                                    setState(() {
                                      w.status = WithdrawStatus.approved;
                                    });
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                            content: Text(
                                                "Approved & Paid ৳${w.amount} to ${w.user}"),
                                            backgroundColor: Colors.green));
                                  },
                                  child: Text("Approve"),
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green),
                                ),
                              if (w.status == WithdrawStatus.pending)
                                SizedBox(width: 7),
                              if (w.status == WithdrawStatus.pending)
                                ElevatedButton(
                                  onPressed: () {
                                    setState(() {
                                      w.status = WithdrawStatus.rejected;
                                      users[w.user]?.balance += w.amount;
                                    });
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                            content: Text(
                                                "Rejected & Refunded ৳${w.amount} to ${w.user}"),
                                            backgroundColor: Colors.red));
                                  },
                                  child: Text("Reject"),
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red),
                                ),
                              if (w.status != WithdrawStatus.pending)
                                Text(
                                  w.status == WithdrawStatus.approved
                                      ? "Approved"
                                      : "Rejected",
                                  style: TextStyle(
                                      color: w.status == WithdrawStatus.approved
                                          ? Colors.green
                                          : Colors.red,
                                      fontWeight: FontWeight.bold),
                                ),
                            ],
                          ),
                        ),
                      );
                    })
                ],
              ),
            ),
          ),
          // User List
          Card(
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("User List",
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Divider(),
                  ...users.values.map((u) => ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.redAccent,
                          child: Text(u.name[0].toUpperCase()),
                        ),
                        title: Text(u.name),
                        trailing: Text("৳${u.balance}",
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                                fontSize: 16)),
                      ))
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
