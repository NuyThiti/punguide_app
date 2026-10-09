import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  static const background = Color(0xFFBEDFCB);
  static const screen = Color(0xFFFFFFFF);
  static const softScreen = Color(0xFFFAFAF8);
  static const createBg = Color(0xFFF6F0E5);
  static const foreground = Color(0xFF1E1E1E);
  static const muted = Color(0xFF7C8782);
  static const line = Color(0xFFF0EDE9);
  static const primary = Color(0xFF5E27E0);
  static const secondary = Color(0xFF5E27E0);
  static const accent = Color(0xFFE89A5F);

  /// Spinners and pull-to-refresh, app-wide.
  static const loading = Color(0xFF5E27E0);

  /// PunGuide brand palette (PaiGun-PunGuide Figma file).
  /// "ไปกัน" action, active tab and the create FAB.
  static const brandOrange = Color(0xFFF4703A);
  static const brandOrangeDeep = Color(0xFFEF4B36);

  /// "ปันไกด์" action.
  static const brandPurple = Color(0xFF7B3FE4);

  /// Bottom navigation, from the "{WIP} Main / Nav Bar" board: dark icons and
  /// grey labels when idle, one coral for the tab in force, and the create
  /// button's coral-to-amber gradient.
  static const navActive = Color(0xFFFF8D72);
  static const navIconIdle = Color(0xFF2C2C2C);
  static const navLabelIdle = Color(0xFF777D79);
  static const createTop = Color(0xFFFF8569);
  static const createBottom = Color(0xFFFFB44F);

  /// Iconex nav icon stroke colour.
  static const navIcon = Color(0xFF483234);
  static const navIconMuted = Color(0xFF9A8F8F);

  /// Creator handle chip on a trip card.
  static const handleChip = Color(0xFFEFF7C9);
  static const handleChipRing = Color(0xFFC8E15F);

  /// Create sheet (Figma 1539-8068): the featured PunGuide card's violet
  /// sweep, its arrow chip, the plain rows' icon well, and the ตกลง button.
  static const createHeroStart = Color(0xFF7C3AED);
  static const createHeroEnd = Color(0xFF31106B);
  static const createHeroArrow = Color(0xFF8B5CF6);
  static const optionIconBg = Color(0xFFF4F2EF);
  static const sheetConfirm = Color(0xFF2B2422);

  /// Create post composer: the grey field wells, the pink plate behind a
  /// location pin, the tag chips and the เผยแพร่โพสต์ button.
  static const postField = Color(0xFFF1F1EF);
  static const postFieldHint = Color(0xFFB2B2AD);
  static const postIconWell = Color(0xFFFFEAE0);
  static const postTagChip = Color(0xFFFFEDE6);
  static const postAction = Color(0xFFFB7452);
  static const postActionIdle = Color(0xFFE6DFDA);

  /// ไปกัน board (Figma 1539-8070): the well behind the location pin, the dark
  /// control beside the address, and the violet distance chip on a card. The
  /// header itself sits on Home's photo rather than a colour of its own.
  /// Create post composer, second pass (design 1967-24885): a dark header over
  /// a white sheet, purple actions, and the photo-import gradient.
  static const postHeader = Color(0xFF19191C);
  static const postPurple = Color(0xFF7C3AED);

  /// The Share button and the Title sheet's ตกลง, a shade deeper than the
  /// accents around them.
  static const postShare = Color(0xFF6D28D9);
  static const postPurpleSoft = Color(0xFFEDE4FF);
  static const postPurpleWell = Color(0xFFF4EEFF);
  /// "AI สร้างโพสจากรูป" (Figma 2502-39595), deepest to lightest — the last
  /// stop is the one the button's own glow leans toward.
  static const postImportStart = Color(0xFF5927FF);
  static const postImportMid = Color(0xFF7C46FA);
  static const postImportMid2 = Color(0xFFCC74FF);
  static const postImportEnd = Color(0xFFD8FF54);
  /// The Create from Photos page's own dark cap (Figma 2480-80792's
  /// "AI-Hero-Card") — a shade lighter than [postHeader], not reused from it.
  static const postImportHeroBg = Color(0xFF2C2C2C);

  /// A sheet's own close chip, beside its title (Figma 2480-80871).
  static const postCloseChip = Color(0xFFE0E0E0);
  /// The "เพิ่มรูป" sheet's icon wells: a plain one for ถ่ายรูป/Video, and the
  /// same purple that highlights เลือกจากคลังภาพ's whole row.
  static const postSourceIconWell = Color(0xFFF0E9FF);
  static const postSourceSelectedRow = Color(0xFFFCF7FF);
  static const postDashed = Color(0xFFD6CDEC);
  static const postRowIcon = Color(0xFF2B2B2E);

  /// The "เพิ่มรูป" empty state (Figma 2480-80673): the illustrated pile of
  /// photos above a heading and a plain, solid pill — no gradient, unlike the
  /// AI button above it.
  static const postEmptyHeading = Color(0xFF2C2C2C);
  static const postEmptySubtitle = Color(0xFF6E7570);
  static const postDraftBg = Color(0xFFF2F1EE);
  static const postToggleBg = Color(0xFFF4F3F1);

  static const paigunPinWell = Color(0xFFFFEDE3);
  static const paigunControl = Color(0xFF1E1A18);
  static const paigunDistance = Color(0xFF7C3AED);

  /// Trip card, measured off Figma 2480-48940. The accent follows the trip's
  /// type: a guide wears lime, a plan wears violet, on the distance chip and
  /// on the little badge in front of the type label.
  static const cardGuideAccent = Color(0xFFE0FE71);
  static const cardPlanAccent = Color(0xFF7549F1);
  static const cardTitle = Color(0xFF1B1D1A);
  static const cardFacts = Color(0xFF6F7570);
  static const cardCoverPill = Color(0xFF1C1714);

  /// ตัวกรอง sheet (Figma 2480-59246): the board darkened behind it, the
  /// grabber, and the peach a chosen chip wears.
  static const filterBackdrop = Color(0xFF2B1511);
  static const filterGrabber = Color(0xFFE2E0DD);
  static const filterChipOn = Color(0xFFFFEDE4);

  static const chipBorder = Color(0xFFE3E0DC);
  static const chipBorderActive = Color(0xFF2B2422);
  static const searchButton = Color(0xFF1A1614);

  /// Location Access (Figma 1576-24479): the permission sheet's allow/later
  /// pair, the map picker's chrome, and the pin it drops.
  static const locationAction = Color(0xFFF97F63);
  static const locationLater = Color(0xFFEFE9DC);
  static const locationLayerWell = Color(0xFFFDEEE2);
  static const locationPin = Color(0xFFF4552D);
  static const locationMapFallback = Color(0xFFE8EDE6);

  /// ตัวกรอง — the ไปกัน filter wizard (Figma 1576-24481): the coral primary,
  /// the peach an answered chip or card wears, the segmented control's track,
  /// and the cream well behind the day wheel's centre row.
  static const filterAction = Color(0xFFF97F63);
  static const filterActionSoft = Color(0xFFFFD0C2);
  static const filterSelected = Color(0xFFFFEDE3);
  static const filterSelectedText = Color(0xFFF4703A);
  static const filterTrack = Color(0xFFF5F1EB);
  static const filterWheelWell = Color(0xFFFFF6EA);
  static const filterStepIdle = Color(0xFFF6E4DA);
  static const filterDivider = Color(0xFFEDE9E3);

  /// Ai Chat (Figma 2281-46309): the assistant's own screen. The spark
  /// gradient is the one [assets/icons/ai_assistant.svg] paints itself with,
  /// so the header pill, the empty state's diamond and the send key all read
  /// as the same object.
  static const aiSparkStart = Color(0xFFFF8569);
  static const aiSparkMid = Color(0xFFFFDB4E);
  static const aiSparkEnd = Color(0xFF80FFAE);

  /// The warm wash behind the page — amber at the crown, gone by the time the
  /// conversation starts, and lit again under the composer.
  static const aiWashTop = Color(0xFFFFE3AE);
  static const aiWashMid = Color(0xFFFFF3DC);
  static const aiWashBottom = Color(0xFFFFEFD8);

  /// Bubbles: the assistant speaks on warm paper, the traveller on graphite.
  static const aiBubbleAssistant = Color(0xFFF2F0ED);
  static const aiBubbleUser = Color(0xFF6E6E6E);

  /// The composer card, its two round tools, and the grey a hint is set in.
  static const aiComposer = Color(0xFFF5F2EE);
  static const aiComposerTool = Color(0xFFEBE7E2);
  static const aiHint = Color(0xFFA9A49E);

  /// The greeting under the diamond.
  static const aiGreeting = Color(0xFF9A9691);
}
