"""Measure live Studio combat and capture three successive frames, without editing scripts.

Run after syncing, in a Studio playtest of the shared place. Only memory profiles
are accepted. Real devices and published four-player tests remain separate gates.
"""
import argparse
import time
import studio_review as review
import studio_sync


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--window-handle', type=int, required=True)
    args = parser.parse_args()
    studio_sync.STUDIO_WINDOW = args.window_handle
    review.prepare(args.window_handle)
    context = review.query('tostring(game.PlaceId)..":"..tostring(game:GetService("RunService"):IsStudio())..":"..tostring(game:GetService("Players").LocalPlayer~=nil)')
    if context != '97132875544830:true:true':
        raise SystemExit('Open the shared place in a Studio playtest.')
    request = 'game:GetService("ReplicatedStorage").DoomRemotes.Request'
    player = 'game:GetService("Players").LocalPlayer'
    guard = f'local r={request}; local s=r:InvokeServer("Sync",{{}}); assert(s.ok and s.data.profile.persistence=="studio-memory", "Memory playtest only");'
    review.command(guard + f'{player}:SetAttribute("DoomReview", "live")', 'REFINE_MEMORY')
    card_map = review.query('require(game:GetService("ReplicatedStorage").DoomShared.Rules).MapsForMode("cards")[1]')
    if not card_map or not card_map.isidentifier():
        raise SystemExit('No card-mode destination in the current catalog.')
    review.command(guard + 'assert(not s.data.match,"Start a fresh playtest; a match is already active")', 'REFINE_LOBBY')
    for command, payload in [('unlock', '{}'), ('give', '{"ironman","hulk","spiderman","thor","hawkeye"}'), ('start', f'"{card_map}"'), ('towers', '{}')]:
        mode = ',modeId="cards"' if command == 'start' else ''
        review.command(guard + f'local answer=r:InvokeServer("StudioReview",{{command="{command}",arg={payload}{mode}}}); assert(answer.ok,"Review {command} failed")', 'REFINE_' + command.upper())
    review.command(guard + 'assert(s.data.match.modeId=="cards" and #s.data.match.towers==5,"Cards roster missing")', 'REFINE_CARDS_READY')
    review.command(f'{player}:SetAttribute("DoomReviewFocus","cam:0,65,110,0,0,0")', 'REFINE_CAMERA')

    def measure(label):
        marker = 'REFINE_PERF_' + label + '_' + str(int(time.time()))
        started = time.time()
        review.command('''local samples,total={},0; local link; link=game:GetService("RunService").RenderStepped:Connect(function(dt) table.insert(samples,dt);total+=dt end)
task.delay(10,function() link:Disconnect(); table.sort(samples); local p95=samples[math.max(1,math.ceil(#samples*.95))] or 0;
print("%s",string.format("frames=%%d fps=%%.1f p95=%%.2fms memory=%%.1fMB",#samples,#samples/math.max(total,.001),p95*1000,game:GetService("Stats"):GetTotalMemoryUsageMb())) end)''' % marker, marker + '_START')
        print(studio_sync.wait_for(marker + ' ', started, 25), flush=True)
        print(label, review.query(f'(function() local s={request}:InvokeServer("Sync",{{}}).data; local m=s.match; local damage,kills=0,0; for _,t in ipairs(m.towers) do damage+=t.totalDamage or 0;kills+=t.kills or 0 end; return string.format("mode=%s phase=%s wave=%d enemies=%d towers=%d damage=%d kills=%d",m.modeId,s.phase,m.wave,m.enemies,#m.towers,damage,kills) end)()'), flush=True)

    measure('BASELINE')
    review.command(guard + 'assert(r:InvokeServer("StudioReview",{command="crowd",arg=80}).ok)', 'REFINE_CROWD')
    review.powershell('-File', str(review.ROOT / 'tools' / 'capture_studio.ps1'), '-WindowHandle', str(args.window_handle),
                      '-OutputPath', 'test-results/refinement/combat-event.png', '-FrameCount', '3', '-FrameIntervalMs', '33')
    measure('CROWD80')
    snapshot = review.query(f'{request}:InvokeServer("Sync",{{}}).data.phase')
    print('Final live phase:', snapshot, flush=True)


if __name__ == '__main__':
    main()
