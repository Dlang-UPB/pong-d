import std.stdio;
import derelict.sdl2.sdl;
import derelict.sdl2.image;
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
                                          640, 480,
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
    static enum dy = 2.;
    // Tolerance
    float eps = 0.001;

    // The state should never be copied
    @disable this(this);

    Ball ball;

    // Initialize the player rackets
    Racket[numPlayers] racket = [Racket(-0.9), Racket(0.9)];

    // Screen limits
    float[2] limits = [-1, 1];
}

struct Ball
{
    vec2f pos = vec2f(0, 0);
    vec2f speed = vec2f(0.4, 0.4);
    float size = 0.01;
}

struct Racket
{
    // Set the racket on the left or right side of the screen
    this(float oxPos)
    {
        oxPosition = oxPos;
    }

    // Default values
    float oyCenter = 0;
    float oxPosition;
    float halfLength = 0.3;
    float halfWidth = 0.01;
    float speed = 0.5;
}

enum Player { One, Two }
enum Direction { Down, Up }

GameState state;

void drawPlayer(int player, ref GameState state)
{
    glPushMatrix();

    glColor3f(1., 1., 1.);
    glTranslated(state.racket[player].oxPosition, state.racket[player].oyCenter, 0.0);
    glBegin(GL_TRIANGLE_STRIP);

    auto halfLength = state.racket[player].halfLength;
    auto halfWidth = state.racket[player].halfWidth;
    glVertex3d(-halfWidth, -halfLength, 0.0);
    glVertex3d(-halfWidth, halfLength, 0.0);
    glVertex3d(halfWidth, -halfLength, 0.0);
    glVertex3d(halfWidth, halfLength, 0.0);
    glEnd();

    glPopMatrix();
}

void drawBall(ref GameState state)
{
    glPushMatrix();

    glColor3f(1., 1., 0.);
    glTranslated(state.ball.pos.x, state.ball.pos.y, 0.0);
    glBegin(GL_TRIANGLE_STRIP);

    auto ballSize = state.ball.size;
    glVertex3d(-ballSize, -ballSize, 0.0);
    glVertex3d(-ballSize, ballSize, 0.0);
    glVertex3d(ballSize, -ballSize, 0.0);
    glVertex3d(ballSize, ballSize, 0.0);
    glColor3f(1., 1., 1.);
    glEnd();

    glPopMatrix();
}

void display(ref SDL_Window *screen, ref GameState state)
{
    // Clear screen
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

    drawPlayer(Player.One, state);
    drawPlayer(Player.Two, state);
    drawBall(state);

    // Swap buffers
    SDL_GL_SwapWindow(screen);
}

void updateBall(ref GameState state, float dt)
{
    state.ball.pos.x += dt * state.ball.speed.x;
    state.ball.pos.y += dt * state.ball.speed.y;
}

void movePlayer(ref GameState state, Player player, Direction dir, float dt)
{
    if (dir == Direction.Up)
    {
        auto newOyCenter = state.racket[player].oyCenter + state.dy * dt * state.racket[player].speed;
        state.racket[player].oyCenter = min(state.limits[dir], newOyCenter);
    }
    else
    {
        auto newOyCenter = state.racket[player].oyCenter - state.dy * dt * state.racket[player].speed;
        state.racket[player].oyCenter = max(state.limits[dir], newOyCenter);
    }
}

/**
 * Recieve an array of artificial "intelligence" players.
 */
void updatePlayers(ref GameState state, Player[] ai, float dt)
{
    for (int i = 0; i < ai.length; ++i)
    {
        uint player = ai[i];
        float yDiff = state.racket[player].oyCenter - state.ball.pos.y;
        if (fabs(yDiff) < state.eps)
            continue;

        float dy = -yDiff / fabs(yDiff);
        state.racket[player].oyCenter += dy * dt * state.racket[player].speed;
    }
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


void updateGameplay(ref GameState state, float dt)
{
    // TMP: define player two as AI
    Player[] ai = [Player.Two];

    checkCollisons(state);
    updateBall(state, dt);
    updatePlayers(state, ai, dt);
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
            default:
                debug(PongD) writefln("Untreated event %s", event.type);
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
            movePlayer(state, Player.One, Direction.Up, dt);
            break;
        case SDLK_DOWN:
            movePlayer(state, Player.One, Direction.Down, dt);
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

bool loadMedia()
{
    //Loading success flag
    bool success = true;

    //Load PNG texture
    gTexture = loadTexture("res/texture.png");
    if(gTexture == null)
    {
        writeln("Failed to load texture image!");
        success = false;
    }

    return success;
}

SDL_Renderer *gRenderer;
SDL_Texture *gTexture;

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
    gTexture = SDL_CreateTexture(gRenderer, SDL_PIXELFORMAT_RGBA8888, SDL_TEXTUREACCESS_TARGET, 1024, 768);

    SDL_Rect r;
    r.w = 100;
    r.h = 20;

    int imgFlags = IMG_INIT_PNG;
    if( !( IMG_Init( imgFlags ) & imgFlags ) )
    {
        writeln( "SDL_image could not initialize! SDL_image Error: %s\n", IMG_GetError() );
    }
    loadMedia();
        //Clear screen
        SDL_RenderClear(gRenderer);

        //Render texture to screen
        SDL_RenderCopy(gRenderer, gTexture, null, null);

        //Update screen
        SDL_RenderPresent(gRenderer);

    while(1)
    {
        SDL_Event event;
        SDL_PollEvent(&event);
        if(event.type == SDL_QUIT)
            break;

        r.x = 100;
        r.y = 100;

        SDL_SetRenderTarget(gRenderer, gTexture);
        SDL_SetRenderDrawColor(gRenderer, 0x00, 0x00, 0x00, 0x00);
        SDL_RenderClear(gRenderer);

        SDL_RenderDrawRect(gRenderer, &r);
        SDL_SetRenderDrawColor(gRenderer, 0xFF, 0x00, 0x00, 0x00);
        SDL_RenderFillRect(gRenderer, &r);

        SDL_SetRenderTarget(gRenderer, null);
        SDL_RenderClear(gRenderer);
        SDL_RenderCopy(gRenderer, gTexture, null, null);
        SDL_RenderPresent(gRenderer);

    }

    bool end = false;
    version(none)
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
