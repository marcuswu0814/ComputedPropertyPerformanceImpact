//
//  ViewController.swift
//  ComputedPropertyPerformanceImpact
//
//  Created by Marcus Wu on 2024/1/9.
//

import ComposableArchitecture
import PinLayout
import RxCocoa
import RxCombine
import RxSwift
import UIKit

class ViewController: UIViewController {

    let viewModel: ViewModel
    
    private let disposeBag = DisposeBag()
    
    private let timeLabel: UILabel = {
        let label = UILabel()
        
        label.font = .systemFont(ofSize: 48, weight: .medium)
        label.textAlignment = .center
        
        return label
    }()
    
    private let aStepper: UIStepper = {
        let stepper = UIStepper()
        
        return stepper
    }()
    
    private let aLabel: UILabel = {
        let label = UILabel()
        
        return label
    }()
    
    private let bStepper: UIStepper = {
        let stepper = UIStepper()
        
        return stepper
    }()
    
    private let bLabel: UILabel = {
        let label = UILabel()
        
        return label
    }()
    
    private let aPlusBLabel: UILabel = {
        let label = UILabel()
        
        label.font = .systemFont(ofSize: 48, weight: .medium)
        label.textAlignment = .center
        
        return label
    }()
    
    init() {
        viewModel = .init()
        
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        viewModel = .init()
        
        super.init(coder: coder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.addSubview(timeLabel)
        view.addSubview(aLabel)
        view.addSubview(bLabel)
        view.addSubview(aStepper)
        view.addSubview(bStepper)
        view.addSubview(aPlusBLabel)
        
        aStepper.rx.value
            .map { Int($0) }
            .subscribe(onNext: { [weak self] in
                self?.viewModel.store.send(.binding(.set(\.$a, $0)))
            })
            .disposed(by: disposeBag)
        bStepper.rx.value
            .map { Int($0) }
            .subscribe(onNext: { [weak self] in
                self?.viewModel.store.send(.binding(.set(\.$b, $0)))
            })
            .disposed(by: disposeBag)
        viewModel.time
            .bind(to: timeLabel.rx.text)
            .disposed(by: disposeBag)
        viewModel.a
            .bind(to: aLabel.rx.text)
            .disposed(by: disposeBag)
        viewModel.b
            .bind(to: bLabel.rx.text)
            .disposed(by: disposeBag)
        viewModel.aPlusB
            .bind(to: aPlusBLabel.rx.text)
            .disposed(by: disposeBag)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        timeLabel.pin
            .horizontally()
            .top(view.pin.safeArea)
            .marginTop(16)
            .height(60)
        
        aLabel.pin
            .top(to: timeLabel.edge.bottom)
            .marginTop(32)
            .left()
            .marginLeft(16)
            .height(30)
            .width(60)
        
        aStepper.pin
            .top(to: timeLabel.edge.bottom)
            .marginTop(32)
            .right()
            .marginRight(16)
            .sizeToFit()
        
        bLabel.pin
            .top(to: aLabel.edge.bottom)
            .marginTop(32)
            .left()
            .marginLeft(16)
            .height(30)
            .width(60)
        
        bStepper.pin
            .top(to: aLabel.edge.bottom)
            .marginTop(32)
            .right()
            .marginRight(16)
            .sizeToFit()
        
        aPlusBLabel.pin
            .top(to: bLabel.edge.bottom)
            .marginTop(32)
            .horizontally()
            .height(60)
    }

}

// MARK: - ViewModel

class ViewModel {
    
    let time: Observable<String>
    
    let a: Observable<String>
    
    let b: Observable<String>
    
    let aPlusB: Observable<String>
    
    let store: StoreOf<Feature>
    
    init() {
        store = .init(initialState: .init()) {
            Feature()
        }
        
        time = store
            .toObservable(\.seconds)
            .map { String($0) }
        a = store
            .toObservable(\.a)
            .map { String($0) }
        b = store
            .toObservable(\.b)
            .map { String($0) }
        aPlusB = store
            .toObservable(\.aPlusB)
            .map { String($0) }
        store.send(.start)
    }
    
    deinit {
        store.send(.end)
    }
    
}

// MARK: - TCA

@Reducer
struct Feature: Reducer {
    
    struct State: Equatable {
        
        var seconds = 0
        
        @BindingState var a = 0
        
        @BindingState var b = 0
        
        var aPlusB = 0
        
        mutating func caculate() {
            aPlusB = a + b
        }
        
    }
    
    enum Action: BindableAction {
    
        case binding(BindingAction<State>)
        
        case start
        
        case end
        
        case timerTicked
        
    }
    
    @Dependency(\.continuousClock) var clock
    
    private enum CancelID { case timer }
    
    var body: some Reducer<State, Action> {
        BindingReducer()
            .onChange(of: \.a) { _, _ in
                Reduce { state, action in
                    state.caculate()
                    
                    return .none
                }
            }
            .onChange(of: \.b) { _, _ in
                Reduce { state, action in
                    state.caculate()
                    
                    return .none
                }
            }
        Reduce(core)
    }
    
    private func core(_ state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .start:
            return .run {send in
                for await _ in self.clock.timer(interval: .seconds(1)) {
                    await send(
                        .timerTicked,
                        animation: .interpolatingSpring(stiffness: 3000, damping: 40)
                    )
                }
            }
            .cancellable(id: CancelID.timer, cancelInFlight: true)
            
        case .end:
            return .cancel(id: CancelID.timer)
            
        case .timerTicked:
            state.seconds += 1
            
        case .binding:
            break
        }
        
        return .none
    }
    
}

// MARK: - Helper

extension Store {
    
    func toObservable<ViewState: Equatable>(
        _ toViewState: @escaping (State) -> ViewState
    ) -> Observable<ViewState> {
        ViewStore(self, observe: toViewState)
            .publisher
            .asObservable()
    }
    
}

