(function () {
  const config = {
    modelUrl: "./models/yzl/yzl.model3.json",
    cubismCoreUrl: "./cubism/live2dcubismcore.min.js",
    pixiUrl: "./vendor/pixi.min.js",
    pixiLive2dUrl: "./vendor/cubism4.min.js"
  };

  const expressionMap = {
    neutral: "",
    gentle: "",
    bright_smile: "wink.exp3",
    happy_smile: "wink.exp3",
    smile: "wink.exp3",
    serious: "",
    angry: "",
    surprise: ""
  };

  const motionMap = {
    idle: "Idle",
    soft_idle: "Idle",
    smile_nod: "Idle",
    excited_wave: "Idle",
    serious_still: "Idle"
  };

  const state = {
    lastPayload: null,
    speaking: false,
    realModelReady: false,
    app: null,
    model: null,
    blobUrls: [],
    animation: {
      time: 0,
      lookX: 0,
      lookY: 0,
      targetLookX: 0,
      targetLookY: -0.04,
      blinkEnabled: true,
      blinkTime: -1,
      nextBlinkIn: 1.4,
      expression: "neutral",
      emotion: "neutral",
      motion: "idle"
    }
  };

  function byId(id) {
    return document.getElementById(id);
  }

  function text(value) {
    if (value === null || value === undefined) {
      return "";
    }
    return String(value);
  }

  function setStatus(value) {
    const status = byId("status");
    if (status) {
      status.textContent = text(value);
    }
  }

  function setLabel(value) {
    const label = byId("stage-label");
    if (label) {
      label.textContent = text(value);
    }
  }

  function setStageDebugVisible(visible) {
    const label = byId("stage-label");
    const status = byId("status");
    if (label) {
      label.style.display = visible ? "block" : "none";
    }
    if (status) {
      status.style.display = visible ? "block" : "none";
    }
  }

  function getRuntimeSummary() {
    const pixiVersion = window.PIXI && window.PIXI.VERSION ? window.PIXI.VERSION : "unknown";
    const live2dVersion =
      window.PIXI && window.PIXI.live2d && window.PIXI.live2d.VERSION
        ? window.PIXI.live2d.VERSION
        : "unknown";

    return "PIXI=" + pixiVersion + ", pixi-live2d-display=" + live2dVersion;
  }

  function loadScript(src) {
    return new Promise((resolve, reject) => {
      const script = document.createElement("script");
      script.src = src;
      script.async = true;
      script.onload = resolve;
      script.onerror = () => reject(new Error("script load failed: " + src));
      document.head.appendChild(script);
    });
  }

  function createObjectUrl(data, mime) {
    if (mime && mime.indexOf("image/") === 0) {
      return "data:" + mime + ";base64," + data;
    }

    const binary = atob(data);
    const bytes = new Uint8Array(binary.length);
    for (let i = 0; i < binary.length; i += 1) {
      bytes[i] = binary.charCodeAt(i);
    }

    const url = URL.createObjectURL(new Blob([bytes], { type: mime }));
    state.blobUrls.push(url);
    return url;
  }

  function createBundledModelUrl() {
    const bundle = window.AIAgentLive2DModelBundle;
    if (!bundle || !bundle.model || !bundle.files) {
      throw new Error("Live2D model bundle missing");
    }

    const model = JSON.parse(JSON.stringify(bundle.model));
    const files = bundle.files;

    if (!files.moc) {
      throw new Error("Live2D moc missing in bundle");
    }

    model.FileReferences.Moc = createObjectUrl(files.moc.data, files.moc.mime);

    if (Array.isArray(model.FileReferences.Textures)) {
      model.FileReferences.Textures = model.FileReferences.Textures.map((_, index) => {
        const file = files["texture_" + index];
        if (!file) {
          throw new Error("Live2D texture missing in bundle: " + index);
        }
        return createObjectUrl(file.data, file.mime);
      });
    }

    delete model.FileReferences.Physics;
    delete model.FileReferences.PhysicsV2;
    delete model.FileReferences.Expressions;
    delete model.FileReferences.Pose;
    delete model.FileReferences.Motions;
    delete model.Controllers;
    delete model.Options;
    model.Groups = [];
    model.HitAreas = [];
    model.Layout = {
      CenterX: 0,
      CenterY: 0,
      Width: 2
    };

    const modelUrl = URL.createObjectURL(
      new Blob([JSON.stringify(model)], { type: "application/json" })
    );
    state.blobUrls.push(modelUrl);
    return modelUrl;
  }

  function installErrorLogging() {
    window.onerror = function (message, source, lineno, colno, error) {
      console.log(
        "AIAgent Live2D uncaught",
        message,
        source + ":" + lineno + ":" + colno,
        error && error.stack ? error.stack : ""
      );
      return false;
    };

    window.onunhandledrejection = function (event) {
      const reason = event && event.reason;
      console.log(
        "AIAgent Live2D rejected",
        reason && reason.message ? reason.message : reason,
        reason && reason.stack ? reason.stack : ""
      );
    };
  }

  async function tryLoadRealLive2D() {
    try {
      showStaticPortrait(true);
      setStageDebugVisible(false);
      setLabel("Loading Live2D runtime...");
      await loadScript(config.cubismCoreUrl);
      await loadScript(config.pixiUrl);
      await loadScript(config.pixiLive2dUrl);
      setLabel("Loading Live2D model... " + getRuntimeSummary());
      await createPixiLive2DModel();
      state.realModelReady = true;
      setLabel("Live2D model loaded");
    } catch (error) {
      state.realModelReady = false;
      setLabel("Live2D fallback");
      showStaticPortrait(true);
    }
  }

  function showStaticPortrait(visible) {
    const portrait = byId("fallback-portrait");
    const fallback = byId("fallback-character");
    const canvas = byId("live2d-canvas");

    if (portrait) {
      portrait.style.display = visible ? "block" : "none";
    }
    if (fallback) {
      fallback.style.display = visible ? "none" : "";
    }
    if (canvas && visible) {
      canvas.style.display = "none";
    }
  }

  function destroyPixiApp(app) {
    try {
      if (app) {
        app.stop();
        app.destroy(false, { children: true, texture: false, baseTexture: false });
      }
    } catch (error) {
      console.log("AIAgent Live2D destroy ignored", error && error.message ? error.message : error);
    }
  }

  async function createPixiLive2DModel() {
    const Live2DModel = getLive2DModelClass();
    if (!Live2DModel || typeof Live2DModel.from !== "function") {
      const live2dKeys = window.PIXI && window.PIXI.live2d
        ? Object.keys(window.PIXI.live2d).join(",")
        : "none";
      throw new Error(
        "Live2DModel.from is not available. " +
          getRuntimeSummary() +
          " PIXI_LIVE2D_KEYS=" +
          live2dKeys +
          ". Use pixi.js 6.5.10 with pixi-live2d-display 0.4.0."
      );
    }

    const canvas = byId("live2d-canvas");
    const fallback = byId("fallback-character");
    if (!canvas) {
      throw new Error("canvas missing");
    }

    const app = new window.PIXI.Application({
      view: canvas,
      autoStart: false,
      resizeTo: window,
      transparent: true,
      backgroundAlpha: 0,
      antialias: true,
      autoDensity: true,
      resolution: window.devicePixelRatio || 1
    });
    app.ticker.maxFPS = 30;

    const model = await Live2DModel.from(createBundledModelUrl(), {
      autoUpdate: false,
      autoInteract: false
    });
    patchCubismCore6Model(model);
    await waitForModelTextures(model);
    warmUpModelTextures(app, model);
    patchInternalModelViewport(app, model);
    model.anchor.set(0.5, 0.5);
    model.alpha = 1;
    model.visible = true;
    fitModelToStage(model);

    app.stage.addChild(model);
    window.addEventListener("resize", () => {
      fitModelToStage(model);
      setInternalModelViewport(app, model);
    });
    installProceduralAnimation(app, model);
    renderStageSafely(app, model);

    canvas.style.display = "block";
    showStaticPortrait(false);
    if (fallback) {
      fallback.style.display = "none";
    }
    app.start();

    state.app = app;
    state.model = model;
    console.log("AIAgent Live2D rendered");
  }

  function warmUpModelTextures(app, model) {
    const contextId = app.renderer.CONTEXT_UID;
    let readyCount = 0;
    model.textures.forEach((texture, index) => {
      const baseTexture = texture && texture.baseTexture;
      if (!baseTexture) {
        throw new Error("Live2D warm-up missing baseTexture: " + index);
      }

      app.renderer.texture.bind(baseTexture, 0);
      if (!baseTexture._glTextures) {
        baseTexture._glTextures = {};
      }

      const glTexture = baseTexture._glTextures[contextId];
      if (glTexture && glTexture.texture) {
        readyCount += 1;
      }
    });

    if (readyCount !== model.textures.length) {
      throw new Error(
        "Live2D WebGL texture warm-up failed: " + readyCount + "/" + model.textures.length
      );
    }
  }

  function renderStageSafely(app, model) {
    try {
      setInternalModelViewport(app, model || state.model);
      app.renderer.render(app.stage);
    } catch (error) {
      console.log(
        "AIAgent Live2D render failed",
        error && error.message ? error.message : error,
        error && error.stack ? error.stack : ""
      );
      showStaticPortrait(true);
      destroyPixiApp(app);
      throw error;
    }
  }

  function setInternalModelViewport(app, model) {
    if (!app || !model || !model.internalModel) {
      return;
    }

    const renderer = app.renderer;
    const width = Math.max(renderer.width || window.innerWidth || 1, 1);
    const height = Math.max(renderer.height || window.innerHeight || 1, 1);
    model.internalModel.viewport = [0, 0, width, height];
  }

  function patchInternalModelViewport(app, model) {
    if (!model || !model.internalModel || typeof model.internalModel.draw !== "function") {
      return;
    }

    const internalModel = model.internalModel;
    if (internalModel.__aiAgentViewportPatched) {
      return;
    }

    const originalDraw = internalModel.draw.bind(internalModel);
    internalModel.draw = function patchedDraw(gl) {
      setInternalModelViewport(app, model);
      return originalDraw(gl);
    };
    internalModel.__aiAgentViewportPatched = true;
  }

  function patchCubismCore6Model(model) {
    const internalModel = model && model.internalModel;
    const coreModel = internalModel && internalModel.coreModel;
    const cubismModel =
      coreModel && typeof coreModel.getModel === "function"
        ? coreModel.getModel()
        : coreModel && coreModel._model;
    const drawables = cubismModel && cubismModel.drawables;

    if (!drawables) {
      return;
    }

    if (!drawables.renderOrders && cubismModel.renderOrders) {
      drawables.renderOrders = cubismModel.renderOrders;
    }
  }

  function installProceduralAnimation(app, model) {
    patchInternalModelUpdate(model);
    installPointerTracking(model);

    app.ticker.add(() => {
      const elapsedMS = Math.min(Math.max(app.ticker.elapsedMS || 16.67, 1), 66.67);
      model.update(elapsedMS);
    });
  }

  function patchInternalModelUpdate(model) {
    const internalModel = model && model.internalModel;
    if (!internalModel || typeof internalModel.update !== "function") {
      return;
    }

    if (internalModel.__aiAgentMotionPatched) {
      return;
    }

    const originalUpdate = internalModel.update.bind(internalModel);
    internalModel.update = function patchedUpdate(deltaMS, elapsedMS) {
      originalUpdate(deltaMS, elapsedMS);
      applyProceduralMotion(model, deltaMS);
    };
    internalModel.__aiAgentMotionPatched = true;
  }

  function installPointerTracking(model) {
    const stage = byId("stage");
    if (!stage || stage.__aiAgentPointerTracking) {
      return;
    }

    stage.addEventListener("pointermove", (event) => {
      const rect = stage.getBoundingClientRect();
      if (!rect.width || !rect.height) {
        return;
      }

      state.animation.targetLookX = clamp((event.clientX - rect.left) / rect.width * 2 - 1, -1, 1);
      state.animation.targetLookY = clamp((event.clientY - rect.top) / rect.height * 2 - 1, -1, 1);
      try {
        if (model && typeof model.focus === "function") {
          model.focus(event.clientX - rect.left, event.clientY - rect.top, true);
        }
      } catch (_) {}
    });

    stage.addEventListener("pointerleave", () => {
      state.animation.targetLookX = 0;
      state.animation.targetLookY = -0.04;
    });

    stage.__aiAgentPointerTracking = true;
  }

  function applyProceduralMotion(model, deltaMS) {
    const coreModel = getCoreModel(model);
    if (!coreModel) {
      return;
    }

    const animation = state.animation;
    const dt = Math.min(Math.max(deltaMS / 1000, 0.001), 0.08);
    animation.time += dt;
    animation.lookX = lerp(animation.lookX, animation.targetLookX, 1 - Math.pow(0.001, dt));
    animation.lookY = lerp(animation.lookY, animation.targetLookY, 1 - Math.pow(0.001, dt));

    const t = animation.time;
    const motionAmount = getMotionAmount(animation.motion);
    const emotionAmount = getEmotionAmount(animation.emotion, animation.expression);
    const idleX = Math.sin(t * 0.9) * 3.4 * motionAmount + Math.sin(t * 0.37) * 1.2;
    const idleY = Math.sin(t * 0.72 + 0.7) * 2.2 * motionAmount;
    const idleZ = Math.sin(t * 0.55 + 1.2) * 2.0 * motionAmount;

    setParam(coreModel, "ParamAngleX", animation.lookX * 18 + idleX);
    setParam(coreModel, "ParamAngleY", -animation.lookY * 12 + idleY);
    setParam(coreModel, "ParamAngleZ", animation.lookX * animation.lookY * -8 + idleZ);
    setParam(coreModel, "ParamBodyAngleX", animation.lookX * 6 + Math.sin(t * 0.62) * 2.8 * motionAmount);
    setParam(coreModel, "ParamBodyAngleY", -animation.lookY * 3 + Math.sin(t * 0.48) * 1.6 * motionAmount);
    setParam(coreModel, "ParamBodyAngleZ", Math.sin(t * 0.44 + 0.8) * 1.8 * motionAmount);
    setParam(coreModel, "ParamEyeBallX", animation.lookX * 0.8);
    setParam(coreModel, "ParamEyeBallY", -animation.lookY * 0.55);
    setParam(coreModel, "ParamBreath", 0.45 + 0.28 * Math.sin(t * 2.0));
    setParam(coreModel, "ParamShoulderY", Math.sin(t * 1.15) * 0.35 * motionAmount);

    const blink = computeBlinkValue(animation, dt);
    setParam(coreModel, "ParamEyeLOpen", blink);
    setParam(coreModel, "ParamEyeROpen", blink);
    setParam(coreModel, "ParamEyeLSmile", emotionAmount.smileEye);
    setParam(coreModel, "ParamEyeRSmile", emotionAmount.smileEye);
    setParam(coreModel, "ParamMouthForm", emotionAmount.mouthForm);
    setParam(coreModel, "ParamCheek", emotionAmount.cheek);
    setParam(coreModel, "ParamBrowLY", emotionAmount.browY);
    setParam(coreModel, "ParamBrowRY", emotionAmount.browY);
    setParam(coreModel, "ParamBrowLForm", emotionAmount.browForm);
    setParam(coreModel, "ParamBrowRForm", emotionAmount.browForm);

    setParam(coreModel, "ParamMouthOpenY", computeMouthOpen(animation, t));

    try {
      coreModel.update();
    } catch (error) {
      console.log("AIAgent Live2D procedural update failed", error && error.message ? error.message : error);
    }
  }

  function getCoreModel(model) {
    const internalModel = model && model.internalModel;
    return internalModel && internalModel.coreModel;
  }

  function setParam(coreModel, id, value) {
    try {
      coreModel.setParameterValueById(id, value);
    } catch (_) {}
  }

  function computeBlinkValue(animation, dt) {
    if (!animation.blinkEnabled) {
      animation.blinkTime = -1;
      animation.nextBlinkIn = 1.6;
      return 1;
    }

    if (animation.blinkTime >= 0) {
      animation.blinkTime += dt;
      const t = animation.blinkTime;
      if (t < 0.07) {
        return 1 - t / 0.07;
      }
      if (t < 0.13) {
        return 0;
      }
      if (t < 0.25) {
        return (t - 0.13) / 0.12;
      }
      animation.blinkTime = -1;
      animation.nextBlinkIn = 2.2 + Math.random() * 3.6;
      return 1;
    }

    animation.nextBlinkIn -= dt;
    if (animation.nextBlinkIn <= 0) {
      animation.blinkTime = 0;
    }
    return 1;
  }

  function computeMouthOpen(animation, t) {
    if (state.speaking) {
      const wave = Math.abs(Math.sin(t * 10.5)) * 0.62 + Math.abs(Math.sin(t * 17.7 + 0.6)) * 0.28;
      return clamp(0.12 + wave, 0, 1);
    }

    if (animation.expression.includes("smile") || animation.emotion.includes("happy")) {
      return 0.08 + Math.max(0, Math.sin(t * 1.8)) * 0.04;
    }

    return 0.02 + Math.max(0, Math.sin(t * 1.2)) * 0.018;
  }

  function getMotionAmount(motion) {
    const value = text(motion).toLowerCase();
    if (value.includes("excited") || value.includes("wave")) {
      return 1.2;
    }
    if (value.includes("still") || value.includes("serious")) {
      return 0.45;
    }
    if (value.includes("nod") || value.includes("smile")) {
      return 0.85;
    }
    return 0.65;
  }

  function getEmotionAmount(emotion, expression) {
    const value = (text(emotion) + " " + text(expression)).toLowerCase();

    if (value.includes("angry")) {
      return {
        mouthForm: -0.55,
        smileEye: 0,
        cheek: 0,
        browY: -0.45,
        browForm: -0.65
      };
    }

    if (value.includes("sad")) {
      return {
        mouthForm: -0.35,
        smileEye: 0,
        cheek: 0,
        browY: -0.3,
        browForm: 0.2
      };
    }

    if (value.includes("surprise")) {
      return {
        mouthForm: 0.1,
        smileEye: 0,
        cheek: 0.1,
        browY: 0.5,
        browForm: 0.2
      };
    }

    if (value.includes("happy") || value.includes("smile") || value.includes("bright")) {
      return {
        mouthForm: 0.75,
        smileEye: 0.42,
        cheek: 0.45,
        browY: 0.15,
        browForm: 0.2
      };
    }

    return {
      mouthForm: 0.12,
      smileEye: 0,
      cheek: 0,
      browY: 0,
      browForm: 0
    };
  }

  function lerp(from, to, amount) {
    return from + (to - from) * amount;
  }

  function clamp(value, min, max) {
    return Math.min(Math.max(value, min), max);
  }

  async function waitForModelTextures(model) {
    if (!model.textures || model.textures.length === 0) {
      throw new Error("Live2D model has no textures");
    }

    const waits = model.textures.map((texture, index) => {
      const baseTexture = texture && texture.baseTexture;
      if (!baseTexture) {
        throw new Error("Live2D texture has no baseTexture: " + index);
      }
      if (baseTexture.valid) {
        return Promise.resolve();
      }

      return new Promise((resolve, reject) => {
        const timer = window.setTimeout(() => {
          reject(new Error("Live2D texture load timeout: " + index));
        }, 8000);

        baseTexture.once("loaded", () => {
          window.clearTimeout(timer);
          resolve();
        });
        baseTexture.once("error", (error) => {
          window.clearTimeout(timer);
          reject(error || new Error("Live2D texture load failed: " + index));
        });
      });
    });

    await Promise.all(waits);
  }

  function fitModelToStage(model) {
    const width = Math.max(window.innerWidth, 1);
    const height = Math.max(window.innerHeight, 1);
    const rawWidth = Math.max(model.internalModel && model.internalModel.width ? model.internalModel.width : 520, 1);
    const rawHeight = Math.max(model.internalModel && model.internalModel.height ? model.internalModel.height : 720, 1);
    const scale = Math.max(Math.min(width * 0.92 / rawWidth, height * 0.96 / rawHeight), 0.25);

    model.x = width / 2;
    model.y = height * 0.68;
    model.scale.set(scale);
  }

  function getLive2DModelClass() {
    if (window.PIXI && window.PIXI.live2d && window.PIXI.live2d.Live2DModel) {
      return window.PIXI.live2d.Live2DModel;
    }

    if (window.Live2DModel) {
      return window.Live2DModel;
    }

    if (window.PIXI && window.PIXI.Live2DModel) {
      return window.PIXI.Live2DModel;
    }

    return null;
  }

  function setSpeaking(speaking) {
    state.speaking = Boolean(speaking);

    const fallback = byId("fallback-character");
    if (fallback) {
      fallback.classList.toggle("speaking", state.speaking);
    }
  }

  function applyPayload(payload) {
    state.lastPayload = payload || {};

    const character = state.lastPayload.character || {};
    const scene = state.lastPayload.scene || {};
    const emotion = text(character.emotion || "neutral");
    const expression = text(character.expression || "neutral");
    const motion = text(character.motion || "idle");
    const backgroundId = text(scene.background_id || "room_default");
    const mouth = character.mouth || {};
    const eye = character.eye || {};

    state.animation.emotion = emotion;
    state.animation.expression = expression;
    state.animation.motion = motion;
    state.animation.blinkEnabled = eye.blink !== false;
    applyLookAt(text(eye.look_at || "user"));
    updateEmotion(emotion);
    updateExpression(expression);
    updateMotion(motion);
    updateBackground(backgroundId);
    setSpeaking(text(mouth.mode) === "audio");

    if (state.realModelReady && state.model) {
      applyRealModelPayload(expression, motion);
      setLabel("Live2D: " + expression + " / " + motion);
    } else {
      setLabel("Fallback: " + expression + " / " + motion);
    }
  }

  function applyRealModelPayload(expression, motion) {
    const mappedExpression = expressionMap[expression] || expression;
    const mappedMotion = motionMap[motion] || motion;

    try {
      if (mappedExpression && state.model.expression) {
        state.model.expression(mappedExpression);
      }
    } catch (_) {}

    try {
      if (mappedMotion && state.model.motion) {
        state.model.motion(mappedMotion);
      }
    } catch (_) {}
  }

  function applyLookAt(value) {
    const lookAt = text(value).toLowerCase();
    if (lookAt === "left") {
      state.animation.targetLookX = -0.45;
      state.animation.targetLookY = -0.02;
      return;
    }
    if (lookAt === "right") {
      state.animation.targetLookX = 0.45;
      state.animation.targetLookY = -0.02;
      return;
    }
    if (lookAt === "down") {
      state.animation.targetLookX = 0;
      state.animation.targetLookY = 0.28;
      return;
    }
    if (lookAt === "up") {
      state.animation.targetLookX = 0;
      state.animation.targetLookY = -0.36;
      return;
    }
    if (lookAt === "away") {
      state.animation.targetLookX = -0.28;
      state.animation.targetLookY = -0.08;
      return;
    }

    state.animation.targetLookX = 0;
    state.animation.targetLookY = -0.04;
  }

  function updateEmotion(emotion) {
    const fallback = byId("fallback-character");
    if (!fallback) {
      return;
    }

    fallback.classList.remove("happy", "sad", "angry");
    if (emotion.includes("happy") || emotion.includes("excited")) {
      fallback.classList.add("happy");
      return;
    }
    if (emotion.includes("sad") || emotion.includes("down")) {
      fallback.classList.add("sad");
      return;
    }
    if (emotion.includes("angry")) {
      fallback.classList.add("angry");
    }
  }

  function updateExpression(expression) {
    const face = byId("fallback-face");
    if (!face) {
      return;
    }

    const value = expression.toLowerCase();
    if (value.includes("smile") || value.includes("happy")) {
      face.textContent = "^_^";
      return;
    }
    if (value.includes("sad")) {
      face.textContent = ";_;";
      return;
    }
    if (value.includes("angry")) {
      face.textContent = ">_<";
      return;
    }
    if (value.includes("surprise")) {
      face.textContent = "o_o";
      return;
    }
    face.textContent = "._.";
  }

  function updateMotion(motion) {
    const motionLabel = byId("motion");
    if (motionLabel) {
      motionLabel.textContent = motion || "idle";
    }
  }

  function updateBackground(backgroundId) {
    const stage = byId("stage");
    if (!stage) {
      return;
    }

    if (backgroundId.includes("night")) {
      stage.style.background =
        "radial-gradient(circle at 50% 18%, rgba(255,255,255,0.72), rgba(72,82,126,0.62) 36%, rgba(33,39,72,0.86) 100%)";
      return;
    }
    if (backgroundId.includes("stage")) {
      stage.style.background =
        "radial-gradient(circle at 50% 18%, rgba(255,255,255,0.92), rgba(255,205,156,0.66) 34%, rgba(171,67,81,0.78) 100%)";
      return;
    }
    stage.style.background =
      "radial-gradient(circle at 50% 18%, rgba(255,255,255,0.95), rgba(255,224,214,0.64) 34%, rgba(255,198,185,0.72) 100%)";
  }

  window.AIAgentLive2D = {
    applyPayload,
    setStatus,
    setSpeaking
  };

  installErrorLogging();
  setStatus("Live2D stage ready");
  tryLoadRealLive2D();
})();
