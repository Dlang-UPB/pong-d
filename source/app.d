import std.stdio;
import derelict.sdl2.sdl;
import derelict.sdl2.image;
import derelict.sdl2.ttf;
import derelict.opengl;
import std.typecons : Tuple;
import std.algorithm.comparison : min, max;
import std.math : fabs;

//mixin glFreeFuncs!(GLVersion.gl33);
//mixin glContext!(GLVersion.gl33);
//GLContext context;

enum maxGLVersion = GLVersion.gl33;
enum supportDeprecated = true;

// Required imports
static if(!supportDeprecated) mixin(glImports);
else mixin(gl_depImports);

// Type declarations should be outside of the struct
mixin glDecls!(maxGLVersion, supportDeprecated);
//struct MyContext {
    mixin glFuncs!(maxGLVersion, supportDeprecated);
    mixin glLoaders!(maxGLVersion, supportDeprecated);
//}
//MyContext context;

enum screenHeight = 480;
enum screenWidth = 640;

void InitSDL(ref SDL_Window *screen, ref SDL_GLContext context)
{
    DerelictGL3.load();

    if (SDL_Init(SDL_INIT_VIDEO) < 0)
    {
        writefln("SDL_Init Error: %s", SDL_GetError());
        return;
    }

    SDL_GL_SetAttribute(SDL_GL_DOUBLEBUFFER, 1);
    SDL_Window *scr = SDL_CreateWindow("Automatic PONG",
                                          SDL_WINDOWPOS_UNDEFINED,
                                          SDL_WINDOWPOS_UNDEFINED,
                                          screenWidth, screenHeight,
                                          SDL_WINDOW_OPENGL);
    if (!scr)
    {
        writefln("Error creating screen: %s", SDL_GetError());
        return;
    }

    context = SDL_GL_CreateContext(scr);

    glEnable(GL_DEPTH_TEST);

    screen = scr;
}

alias vec2f = Tuple!(float, "x", float, "y");

struct GameState
{
    static enum numPlayers = 2;
    // Distance moved by one key press on the OY axis
    static enum dy = 20.;
    // Tolerance
    float eps = 0.001;

    // The state should never be copied
    @disable this(this);

    Ball ball;

    // Initialize the player rackets
    Racket[numPlayers] racket = [Racket(-0.9), Racket(0.9)];

    // Screen limits
    float[2] limits = [-1, 1];

    Score score;
    SDL_Texture* backgroundTexture;
}

struct Score
{
    enum fontSize = 100;
    vec2f pos = vec2f(-0.16, -1);
    float fontWidth = 0.3;
    float fontHeight = 0.3;

    // Score for the two players
    int[2] score;
    SDL_Color textColor = {255,255,255};
    TTF_Font* font;
    SDL_Surface* textSurface;
    SDL_Texture* fontTexture;

    void adjustScore()
    {
        import std.string : toStringz;
        import std.conv : to;
        import core.stdc.stdlib : free;

        string text = to!string(score[0], 10) ~ " - " ~ to!string(score[1], 10);
        free(textSurface);
        free(fontTexture);
        textSurface = TTF_RenderText_Solid(font, toStringz(text), textColor);
        fontTexture = SDL_CreateTextureFromSurface(gRenderer, textSurface);
    }
}

struct Ball
{
    vec2f pos = vec2f(0, 0);
    vec2f speed = vec2f(0.7, 0.7);
    float size = 0.03;
    SDL_Texture* ballTexture;

    void reset()
    {
        pos = vec2f(0, 0);
        speed = vec2f(0.7, 0.7);
        size = 0.03;
    }
}

struct Racket
{
    // Set the racket on the left or right side of the screen
    this(float oxPos)
    {
        oxPosition = oxPos;
    }

    void reset(int player)
    {
        oyCenter = 0;
        halfLength = 0.3;
        halfWidth = 0.01;

        if (player == Player.One)
        {
            speed = 0;
            oxPosition = -0.9;
        }
        else
        {
            speed = 0.5;
            oxPosition = 0.9;
        }
    }

    // Default values
    float oyCenter = 0;
    float oxPosition = 0;
    float halfLength = 0.3;
    float halfWidth = 0.01;
    float speed = 0.5;
    SDL_Texture* playerTexture;
}

enum Player { One, Two }
enum Direction { Down, Up }

GameState state;

void drawPlayer(int player, ref GameState state)
{
    SDL_Rect r;
    auto racket = state.racket[player];
    r.x = cast(int) ((racket.oxPosition - racket.halfWidth + 1) * (screenWidth / 2));
    r.y = cast(int) ((2 - (racket.oyCenter + racket.halfLength + 1)) * (screenHeight / 2));
    r.w = cast(int) ((2 * racket.halfWidth) * (screenWidth / 2));
    r.h = cast(int) ((2 * racket.halfLength) * (screenHeight / 2));

    //Update screen
    SDL_RenderCopy(gRenderer, racket.playerTexture, null, &r);
}

void drawBall(ref GameState state)
{
    SDL_Rect r;
    auto ball = state.ball;
    r.x = cast(int) ((ball.pos.x - ball.size + 1) * (screenWidth / 2));
    r.y = cast(int) ((2 - (ball.pos.y + ball.size + 1)) * (screenHeight / 2));
    r.w = cast(int) ((2 * ball.size) * (screenWidth / 2));
    r.h = cast(int) ((2 * ball.size) * (screenHeight / 2));

    //Update screen
    SDL_RenderCopy(gRenderer, ball.ballTexture, null, &r);
}

void drawScore(ref GameState state)
{
    auto score = state.score;
    SDL_Rect r;
    r.x = cast(int) ((score.pos.x + 1) * (screenWidth / 2));
    r.y = cast(int) ((score.pos.y + 1) * (screenHeight / 2));
    r.w = cast(int) ((score.fontWidth) * (screenWidth / 2));
    r.h = cast(int) ((score.fontHeight) * (screenHeight / 2));

    SDL_RenderCopy(gRenderer, score.fontTexture, null, &r);
}


void display(ref SDL_Window *screen, ref GameState state)
{
    //Clear screen
    SDL_RenderClear(gRenderer);
    SDL_SetRenderDrawColor(gRenderer, 0xFF, 0xFF, 0xFF, 0xFF);

    //Render texture to screen
    SDL_RenderCopy(gRenderer, state.backgroundTexture, null, null);

    drawPlayer(Player.One, state);
    drawPlayer(Player.Two, state);
    drawBall(state);
    drawScore(state);

    SDL_RenderPresent(gRenderer);
}

void updateBall(ref GameState state, float dt)
{
    state.ball.pos.x += dt * state.ball.speed.x;
    state.ball.pos.y += dt * state.ball.speed.y;
}

void movePlayer(ref GameState state, int player, float dt)
{
    auto newOyCenter = state.racket[player].oyCenter + dt * state.racket[player].speed;
    state.racket[player].oyCenter = min(state.limits[1], newOyCenter);
    state.racket[player].oyCenter = max(state.limits[0], newOyCenter);
}

/**
 * Recieve an array of artificial "intelligence" players.
 */
void updatePlayers(ref GameState state, float dt)
{
    movePlayer(state, Player.One, dt);

    float yDiff = state.racket[Player.Two].oyCenter - state.ball.pos.y;
    if (fabs(yDiff) < state.eps)
        return;

    float dy = -yDiff / fabs(yDiff);
    state.racket[Player.Two].oyCenter += dy * dt * state.racket[Player.Two].speed;
}

void checkCollisons(ref GameState state)
{
    // Check collision with left player
    if (state.ball.speed.x < 0)
    {
        if (state.ball.pos.x <= state.racket[Player.One].oxPosition + state.racket[Player.One].halfWidth &&
            fabs(state.ball.pos.y - state.racket[Player.One].oyCenter) < state.racket[Player.One].halfLength)
        {
            state.ball.speed.x *= -1;
        }
    }

    // Check collision with right player
    if (state.ball.speed.x > 0)
    {
        if (state.ball.pos.x >= state.racket[Player.Two].oxPosition - state.racket[Player.Two].halfWidth &&
            fabs(state.ball.pos.y - state.racket[Player.Two].oyCenter) < state.racket[Player.Two].halfLength)
        {
            state.ball.speed.x *= -1;
        }
    }

    // Check collision with lower bound of the screen
    if (state.ball.pos.y <= state.limits[0])
        state.ball.speed.y *= -1;

    // Check collision with the upper bound of the screen
    if (state.ball.pos.y >= state.limits[1])
        state.ball.speed.y *= -1;
}

bool checkGameOver(ref GameState state)
{
    if (state.ball.pos.x <= state.limits[0])
    {
        state.score.score[Player.One]++;
        return true;
    }

    if (state.ball.pos.x >= state.limits[1])
    {
        state.score.score[Player.Two]++;
        return true;
    }

    return false;
}

void updateGameplay(ref GameState state, float dt)
{
    if (checkGameOver(state))
        initGame(state);
    checkCollisons(state);
    updateBall(state, dt);
    updatePlayers(state, dt);
}

/**
 * Process events from user.
 *
 * Returns:
 *      `true` if user wants to quit; `false` otherwise.
 */
bool processEvents(ref GameState state, float dt)
{
    // Check events
    SDL_Event event;
    while (SDL_PollEvent(&event))
    {
        switch (event.type)
        {
            case SDL_QUIT:
                // Quit the program
                return true;
            case SDL_KEYDOWN:
                processKeydownEv(event, state, dt);
                break;
            case SDL_KEYUP:
                processKeyupEv(event, state, dt);
                break;
            default:
                debug(PongD) writefln("Untreated event %s", event.type);
                break;
        }
    }
    return false;
}

/**
 * Process keyboard events from user.
 */
void processKeydownEv(ref SDL_Event event, ref GameState state, float dt)
{
    switch (event.key.keysym.sym)
    {
        case SDLK_UP:
            state.racket[Player.One].speed = 0.5;
            break;
        case SDLK_DOWN:
            state.racket[Player.One].speed = -0.5;
            break;
        default:
            debug (PongD) writefln("pressed %s", event.key.keysym);
    }
}

/**
 * Process keyboard events from user.
 */
void processKeyupEv(ref SDL_Event event, ref GameState state, float dt)
{
    switch (event.key.keysym.sym)
    {
        case SDLK_UP:
            state.racket[Player.One].speed = 0;
            break;
        case SDLK_DOWN:
            state.racket[Player.One].speed = 0;
            break;
        default:
            debug (PongD) writefln("pressed %s", event.key.keysym);
    }
}

SDL_Texture* loadTexture(const(char)[] path)
{
    //The final texture
    SDL_Texture* newTexture = null;

    //Load image at specified path
    SDL_Surface* loadedSurface = IMG_Load(path.ptr);
    if(loadedSurface == null)
    {
        writefln("Unable to load image %s! SDL_image Error: %s\n", path, IMG_GetError());
    }
    else
    {
        //Create texture from surface pixels
        newTexture = SDL_CreateTextureFromSurface(gRenderer, loadedSurface);
        if(newTexture == null)
        {
            writefln("Unable to create texture from %s! SDL Error: %s\n", path, SDL_GetError());
        }

        //Get rid of old loaded surface
        SDL_FreeSurface(loadedSurface);
    }

    return newTexture;
}

bool loadMedia(ref GameState state)
{
    import std.string : toStringz;

    //Loading success flag
    bool success = true;
    SDL_Texture* backgroundTexture;
    SDL_Texture* playerOneTexture;
    SDL_Texture* playerTwoTexture;
    SDL_Texture* ballTexture;
    const(char[]) fontpath = "/usr/share/fonts/truetype/freefont/FreeSerif.ttf";
    SDL_Texture* fontTexture;
    SDL_Surface* textSurface;
    TTF_Font* font;

    //Load PNG texture
    backgroundTexture = loadTexture("res/background.png");
    if(backgroundTexture == null)
    {
        writeln("Failed to load background texture image!");
        success = false;
        goto end;
    }
    state.backgroundTexture = backgroundTexture;

    playerOneTexture = loadTexture("res/playerOne.png");
    if(playerOneTexture == null)
    {
        writeln("Failed to load player one texture image!");
        success = false;
        goto end;
    }
    state.racket[Player.One].playerTexture = playerOneTexture;

    playerTwoTexture = loadTexture("res/playerTwo.png");
    if(playerTwoTexture == null)
    {
        writeln("Failed to load player two texture image!");
        success = false;
        goto end;
    }
    state.racket[Player.Two].playerTexture = playerTwoTexture;

    ballTexture = loadTexture("res/ball.png");
    if(ballTexture == null)
    {
        writeln("Failed to load ball texture image!");
        success = false;
        goto end;
    }
    state.ball.ballTexture = ballTexture;

    font = TTF_OpenFont(fontpath.ptr, state.score.fontSize);
    if (font is null)
    {
        writefln("TTF_OpenFont: %s\n", TTF_GetError());
        success = false;
        goto end;
    }
    state.score.font = font;

end:
    return success;
}

SDL_Renderer *gRenderer;

void initGame(ref GameState state)
{
    state.racket[Player.One].reset(Player.One);
    state.racket[Player.Two].reset(Player.Two);
    state.ball.reset();
    state.score.adjustScore();
}

void main()
{
    import std.conv : to;
    SDL_Window * screen = null;
    SDL_GLContext context = null;

    auto prevTicks = SDL_GetTicks();
    float deltaTimeConstant = 1000.;
    InitSDL(screen, context);

    SDL_RendererFlags none;
    gRenderer = SDL_CreateRenderer(screen, -1, none);

    int imgFlags = IMG_INIT_PNG;
    if(!(IMG_Init(imgFlags) & imgFlags))
    {
        writeln("SDL_image could not initialize! SDL_image Error: %s\n", IMG_GetError());
        return;
    }

    // For fonts
    if (TTF_Init() < 0)
    {
        writeln("TTF_Init error");
    }

    if (!loadMedia(state))
    {
        writeln("Failed to load media");
        return;
    }
    initGame(state);

    bool end = false;
    while(!end)
    {
        auto currentTicks = SDL_GetTicks();
        float dt = (currentTicks - prevTicks) / deltaTimeConstant;
        prevTicks = currentTicks;

        end = processEvents(state, dt);

        updateGameplay(state, dt);
        display(screen, state);
    }

    scope(exit) SDL_Quit();
    SDL_GL_DeleteContext(context);
}
