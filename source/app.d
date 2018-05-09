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

/**
 * Screen height constant
 */
enum screenHeight = 480;

/**
 * Screen width constant
 */
enum screenWidth = 640;

/**
 * Initializes the SDL library for drawing functionality.
 */
void InitSDL(ref SDL_Window *screen, ref SDL_GLContext context)
{
    DerelictGL3.load();

    if (SDL_Init(SDL_INIT_VIDEO) < 0)
    {
        writefln("SDL_Init Error: %s", SDL_GetError());
        return;
    }

    SDL_GL_SetAttribute(SDL_GL_DOUBLEBUFFER, 1);
    SDL_Window *scr = SDL_CreateWindow("D Pong",
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

/**
 * Holds the global state of the game.
 * It has references to the two players by means of the `Racket[numPlayers] racket` array.
 * It also holds the ball object (`Ball ball`) and the score (`Score score`).
 * The `float[2] limits` array represents the limits of the screen. On the Xaxis, the leftmost point is
 * `-1` and the rightmost is `1`.
 * On the Yaxis, the top of the screen is `1` and the bottom part is `-1`.
 */
struct GameState
{
    static enum numPlayers = 2;
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

/**
 * The stucture that represents the game `Score`.
 * This holds an `int[2]` array which represent the score for the first and second player.
 *
 * Whenever a player wins a round, we will increment his score in the `checkGameOver` function.
 * When the rounds restarts, inside the `initGame` function, we will adjust the score by calling
 * `adjustScore`.
 */
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

/**
 * The structure that represents the `Ball` from the game.
 * Each `Racket` contains a `vec2f` representing the x and y coordinates. (`pos.x` and `pos.y`) $(BR)
 * Each frame, the ball updates its position based on the `speed` member.
 *
 * When colliding with a player, we can increase the speed of the ball by calling the `increaseSpeed`
 * method.
 */
struct Ball
{
    vec2f pos = vec2f(0, 0);
    vec2f speed = vec2f(0.5, 0.5);
    float size = 0.03;
    SDL_Texture* ballTexture;

    void reset()
    {
        pos = vec2f(0, 0);
        speed = vec2f(0.7, 0.7);
        size = 0.03;
    }

    void increaseSpeed()
    {
        import std.random;
        auto rnd = Random();

        float extraX = uniform(0.1, 0.2, rnd);
        float extraY = uniform(0.1, 0.2, rnd);
        if (speed.x <= 0)
            speed.x -= extraX;
        else speed.x += extraX;

        if (speed.y <= 0)
            speed.y -= extraY;
        else speed.y += extraY;
    }
}

/**
 * The structure that represents a player.
 * Each `Racket` contains a `vec2f` representing the x and y coordinates. (`pos.x` and `pos.y`) $(BR)
 * The dimensions of the `racket` are accessible through `halfLength` and `halfWidth`.
 * The Yaxis coordinate is updated each frame based on the `speed` member.
 */
struct Racket
{
    // Set the racket on the left or right side of the screen
    this(float x)
    {
        pos.x = x;
    }

    void reset(int player)
    {
        pos.y = 0;
        halfLength = 0.3;
        halfWidth = 0.01;

        if (player == Player.One)
        {
            speed = 0;
            pos.x = -0.9;
        }
        else
        {
            speed = 0.8;
            pos.x = 0.9;
        }
    }

    // Default values
    vec2f pos = vec2f(0, 0);
    float halfLength = 0.3;
    float halfWidth = 0.01;
    float speed = 0.5;
    SDL_Texture* playerTexture;
}

enum Player { One, Two }
enum Direction { Down, Up }

GameState state;

/**
 * Draws the players `state.racket[player].playerTexture`.
 *
 * Params:
 *  player = index of the player that is drawn
 *  state = The state of the game including positions and speeds of players and ball
 */
void drawPlayer(int player, ref GameState state)
{
    SDL_Rect r;
    auto racket = state.racket[player];
    r.x = cast(int) ((racket.pos.x - racket.halfWidth + 1) * (screenWidth / 2));
    r.y = cast(int) ((2 - (racket.pos.y + racket.halfLength + 1)) * (screenHeight / 2));
    r.w = cast(int) ((2 * racket.halfWidth) * (screenWidth / 2));
    r.h = cast(int) ((2 * racket.halfLength) * (screenHeight / 2));

    //Update screen
    SDL_RenderCopy(gRenderer, racket.playerTexture, null, &r);
}

/**
 * Draws the ball using `state.ball.ballTexture`.
 *
 * Params:
 *  state = The state of the game including positions and speeds of players and ball
 */
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

/**
 * Draws the score using the font texture from `state.score.fontTexture`.
 *
 * Params:
 *  state = The state of the game including positions and speeds of players and ball
 */
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

/**
 * Draws the background using the `state.backgroundTexture`.
 *
 * Params:
 *  state = The state of the game including positions and speeds of players and ball
 */
void drawBackground(ref GameState state)
{
    //Render texture to screen
    SDL_RenderCopy(gRenderer, state.backgroundTexture, null, null);
}

/**
 * Does all the rendering in the following order: $(BR)
 * 1. Draws the background $(BR)
 * 2. Draws the two players $(BR)
 * 3. Draws the ball $(BR)
 * 4. Draws the score $(BR)
 */
void display(ref SDL_Window *screen, ref GameState state)
{
    //Clear screen
    SDL_RenderClear(gRenderer);
    SDL_SetRenderDrawColor(gRenderer, 0xFF, 0xFF, 0xFF, 0xFF);

    drawBackground(state);
    drawPlayer(Player.One, state);
    drawPlayer(Player.Two, state);
    drawBall(state);
    drawScore(state);

    SDL_RenderPresent(gRenderer);
}

/**
 * Updates the position of the ball, based on its speed.
 *
 * Params:
 *  state = The state of the game including positions and speeds of players and ball
 *  dt = the CPU time between frames used for computations
 */
void updateBall(ref GameState state, float dt)
{
    auto ball = &state.ball;
    ball.pos.x += dt * ball.speed.x;
    ball.pos.y += dt * ball.speed.y;
}

/**
 * Implements the logic for the human player.
 * The player will update its Yaxis position (`player.pos.y`) based on the speed (`player.speed`).
 * We also need to check that the player Yaxis position remains inside the screen.
 * (`state.limits[1] <= player.pos.y`) and (`state.limits[0] >= player.pos.y`)
 *
 *
 * Params:
 *  state = The state of the game including positions and speeds of players and ball
 *  dt = the CPU time between frames used for computations
 */
void moveHumanPlayer(ref GameState state, float dt)
{
    auto player = &state.racket[Player.One];
    player.pos.y += dt * player.speed;

    player.pos.y = min(state.limits[1], player.pos.y);
    player.pos.y = max(state.limits[0], player.pos.y);
}

/**
 * Implements the logic for the AI player.
 * The AI just follows the position of the ball.
 *
 * Params:
 *  state = The state of the game including positions and speeds of players and ball
 *  dt = the CPU time between frames used for computations
 */
void moveAIPlayer(ref GameState state, float dt)
{
    auto player = &state.racket[Player.Two];
    auto ball = &state.ball;

    float yDiff = player.pos.y - ball.pos.y;
    if (fabs(yDiff) < state.eps)
        return;

    float dy = -yDiff / fabs(yDiff);
    player.pos.y += dy * dt * player.speed;
}

/**
 * Updates the position of the human (`Player.One`) and AI (`Player.two`) players.
 * Params:
 *  state = The state of the game including positions and speeds of players and ball
 *  dt = the CPU time between frames used for computations
 */
void updatePlayers(ref GameState state, float dt)
{
    moveHumanPlayer(state, dt);
    moveAIPlayer(state, dt);
}

/**
 * Verifies all collisions in the game. They should be checked in the following order: $(BR)
 * 1. If the ball moves to the left (ball speed is negative), check ball collision with the left player $(BR)
 * 2. If the ball moves to the right (ball speed is positive), check ball collision with the right player $(BR)
 * 3. Check if the ball hits the top of bottom of the screen $(BR)
 * $(BR)
 * If the ball collides with a player, the ball has to reverse its speed on the Xaxis (`ball.speed.x *= -1`) $(BR)
 * If the ball collides the top or bottom of the screen, the ball has to reverse its speed on the Yaxis (`ball.speed.y *= -1`) $(BR)
 */
void checkCollisons(ref GameState state)
{
    auto ball = &state.ball;
    auto playerOne = &state.racket[Player.One];
    auto playerTwo = &state.racket[Player.Two];

    // Check collision with left player
    if (ball.speed.x < 0)
    {
        if (ball.pos.x <= playerOne.pos.x + playerOne.halfWidth &&
            fabs(ball.pos.y - playerOne.pos.y) < playerOne.halfLength)
        {
            ball.speed.x *= -1;
            ball.increaseSpeed();
        }
    }

    // Check collision with right player
    if (ball.speed.x > 0)
    {
        if (ball.pos.x >= playerTwo.pos.x - playerTwo.halfWidth &&
            fabs(ball.pos.y - playerTwo.pos.y) < playerTwo.halfLength)
        {
            ball.speed.x *= -1;
            ball.increaseSpeed();
        }
    }

    // Check collision with lower bound of the screen
    if (ball.pos.y <= state.limits[0] || ball.pos.y >= state.limits[1])
        ball.speed.y *= -1;
}

/**
 * Checks the status of the game.
 * If the ball reaches the right or left of the screen, the current round is over
 * and we give points to the winning player.
 *
 * Returns:
 *  `true` if the game is over and `false` otherwise
 */
bool checkGameOver(ref GameState state)
{
    auto ball = &state.ball;
    auto score = &state.score;

    if (ball.pos.x <= state.limits[0])
    {
        score.score[Player.Two]++;
        return true;
    }

    if (ball.pos.x >= state.limits[1])
    {
        score.score[Player.One]++;
        return true;
    }

    return false;
}

/**
 * This is called every frame and does the following things in the specified order: $(BR)
 *  1. Checks if the game is over and resets the round $(BR)
 *  2. Computes collisions between ball and rackets $(BR)
 *  3. Updates the position of the ball $(BR)
 *  4. Updates the position of the players $(BR)
 *
 * Params:
 *  state = The state of the game including positions and speeds of players and ball
 *  dt = the CPU time between frames used for computations
 */
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
 * Currently we only check arrow key presses. If an arrow is pressed (`SDL_KEYDOWN`) we call the `processKeydownEv`.
 * Otherwise `processKeyupEv` is called.
 *
 * Params:
 *  state = The state of the game including positions and speeds of players and ball
 *  dt = the CPU time between frames used for computations
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
 * Process keyboard press events from user.
 * If the up and down arrows are pressed, the player speed is adjusted.
 */
void processKeydownEv(ref SDL_Event event, ref GameState state, float dt)
{
    auto player = &state.racket[Player.One];
    switch (event.key.keysym.sym)
    {
        case SDLK_UP:
            player.speed = 0.5;
            break;
        case SDLK_DOWN:
            player.speed = -0.5;
            break;
        default:
            debug (PongD) writefln("pressed %s", event.key.keysym);
    }
}

/**
 * Process keyboard up events from the user.
 * If the user stopped pressing the up and down arrow keys, the speed is set to `0`.
 */
void processKeyupEv(ref SDL_Event event, ref GameState state, float dt)
{
    auto player = &state.racket[Player.One];
    switch (event.key.keysym.sym)
    {
        case SDLK_UP:
            player.speed = 0;
            break;
        case SDLK_DOWN:
            player.speed = 0;
            break;
        default:
            debug (PongD) writefln("pressed %s", event.key.keysym);
    }
}

/**
 * Loads a single texture in memory
 * Params:
 *  path = path to a image which will be used in the game as a texture
 * Returns:
 *  The newly loaded texture
 */
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

/**
 * Loads all resources, including: background, ball, player textures and fonts for the score
 */
bool loadMedia(ref GameState state)
{
    import std.string : toStringz;

    //Loading success flag
    bool success = true;
    SDL_Texture* backgroundTexture;
    SDL_Texture* playerOneTexture;
    SDL_Texture* playerTwoTexture;
    SDL_Texture* ballTexture;
    const(char[]) fontpath = "./res/FreeSerifBold.ttf";
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

/**
 * Resets the game by moving each object to a default position and updates the score.
 */
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
